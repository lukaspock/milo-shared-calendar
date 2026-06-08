import db from "../db/client";
import { signToken } from "../middleware/auth.middleware";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { sendVerificationEmail, sendPasswordResetEmail } from "../services/email";
import { google } from "googleapis";
import { generateCalendarConnectUrl, handleCalendarCallback } from "../services/google_calendar";
import { cleanupAssets } from "../services/cloudinary";

export async function register(ctx: RequestContext): Promise<Response> {
  let body: { email?: string; password?: string; name?: string; notification_type?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { email, password, name } = body;
  if (!email || !password || !name) {
    return error("email, password and name are required");
  }
  if (password.length < 6) {
    return error("Password must be at least 6 characters");
  }
  const notificationType = body.notification_type === "push" ? "push" : "email";

  const existing = await db`SELECT id FROM users WHERE email = ${email}`;
  if (existing.length > 0) {
    return error("Email already in use", 409);
  }

  const passwordHash = await Bun.password.hash(password);

  const colors = ["#6C63FF", "#FF6584", "#43B89C", "#F5A623", "#4A90E2", "#E74C3C", "#2ECC71", "#9B59B6"];
  const countResult = await db`SELECT COUNT(*)::integer AS count FROM users`;
  const idx = (countResult[0].count as number) % colors.length;
  const color = colors[idx];

  const verificationToken = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  const users = await db`
    INSERT INTO users (email, password_hash, name, color, notification_type, verification_token, verification_expires_at)
    VALUES (${email}, ${passwordHash}, ${name}, ${color}, ${notificationType}, ${verificationToken}, ${expiresAt})
    RETURNING id, email, name, color, notification_type, email_verified, created_at
  `;
  const user = users[0];

  // Fire-and-forget — don't block the response
  sendVerificationEmail(email, name, verificationToken).catch(console.error);

  const token = await signToken({ sub: user.id, email: user.email, name: user.name });

  return json({
    token,
    user: {
      id: user.id, email: user.email, name: user.name, color: user.color,
      notification_type: user.notification_type, email_verified: false,
    },
  }, 201);
}

export async function login(ctx: RequestContext): Promise<Response> {
  let body: { email?: string; password?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { email, password } = body;
  if (!email || !password) {
    return error("email and password are required");
  }

  const users = await db`SELECT * FROM users WHERE email = ${email}`;
  if (users.length === 0) {
    return error("Invalid credentials", 401);
  }

  const user = users[0];
  const valid = await Bun.password.verify(password, user.password_hash);
  if (!valid) {
    return error("Invalid credentials", 401);
  }

  const token = await signToken({ sub: user.id, email: user.email, name: user.name });

  return json({
    token,
    user: {
      id: user.id, email: user.email, name: user.name, color: user.color,
      notification_type: user.notification_type ?? "email",
      email_verified: user.email_verified ?? false,
      avatar_url: user.avatar_url ?? null,
    },
  });
}

export async function verifyEmail(ctx: RequestContext): Promise<Response> {
  const { token } = ctx.params;

  const users = await db`
    SELECT id, name, verification_expires_at FROM users
    WHERE verification_token = ${token}
  `;

  if (users.length === 0) {
    return new Response(errorPage("Invalid or already used verification link."), {
      status: 400, headers: { "Content-Type": "text/html" },
    });
  }

  const user = users[0];
  if (new Date(user.verification_expires_at) < new Date()) {
    return new Response(errorPage("This verification link has expired. Please request a new one in the app."), {
      status: 400, headers: { "Content-Type": "text/html" },
    });
  }

  await db`
    UPDATE users
    SET email_verified = true, verification_token = null, verification_expires_at = null
    WHERE id = ${user.id}
  `;

  return new Response(successPage(user.name), {
    status: 200, headers: { "Content-Type": "text/html" },
  });
}

export async function resendVerification(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;

  const users = await db`SELECT id, email, name, email_verified FROM users WHERE id = ${userId}`;
  if (users.length === 0) return error("User not found", 404);
  const user = users[0];

  if (user.email_verified) return json({ message: "Email is already verified" });

  const token = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  await db`
    UPDATE users
    SET verification_token = ${token}, verification_expires_at = ${expiresAt}
    WHERE id = ${userId}
  `;

  sendVerificationEmail(user.email, user.name, token).catch(console.error);

  return json({ message: "Verification email sent" });
}

export async function getMe(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const users = await db`
    SELECT id, email, name, color, notification_type, email_verified, avatar_url FROM users WHERE id = ${userId}
  `;
  if (users.length === 0) return error("User not found", 404);
  const user = users[0];
  const gcal = await db`SELECT 1 FROM google_calendar_tokens WHERE user_id = ${userId}`;
  return json({
    id: user.id, email: user.email, name: user.name,
    color: user.color, notification_type: user.notification_type ?? "email",
    email_verified: user.email_verified ?? false,
    has_google_calendar: gcal.length > 0,
    avatar_url: user.avatar_url ?? null,
  });
}

export async function updateProfile(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  let body: { name?: string; color?: string; avatar_url?: string | null };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { name, color, avatar_url } = body;
  if (!name && !color && avatar_url === undefined) {
    return error("Provide at least one of: name, color, avatar_url");
  }
  if (name !== undefined && name.trim().length === 0) {
    return error("Name cannot be empty");
  }

  const users = await db`SELECT id, avatar_url FROM users WHERE id = ${userId}`;
  if (users.length === 0) return error("User not found", 404);
  const oldAvatarUrl = users[0].avatar_url as string | null;

  // Build the update dynamically — only set fields that were provided
  if (name && color && avatar_url !== undefined) {
    await db`UPDATE users SET name = ${name.trim()}, color = ${color}, avatar_url = ${avatar_url ?? null} WHERE id = ${userId}`;
  } else if (name && color) {
    await db`UPDATE users SET name = ${name.trim()}, color = ${color} WHERE id = ${userId}`;
  } else if (name && avatar_url !== undefined) {
    await db`UPDATE users SET name = ${name.trim()}, avatar_url = ${avatar_url ?? null} WHERE id = ${userId}`;
  } else if (color && avatar_url !== undefined) {
    await db`UPDATE users SET color = ${color}, avatar_url = ${avatar_url ?? null} WHERE id = ${userId}`;
  } else if (name) {
    await db`UPDATE users SET name = ${name.trim()} WHERE id = ${userId}`;
  } else if (color) {
    await db`UPDATE users SET color = ${color} WHERE id = ${userId}`;
  } else {
    await db`UPDATE users SET avatar_url = ${avatar_url ?? null} WHERE id = ${userId}`;
  }

  // Clean up old Cloudinary avatar if it changed or was removed
  if (avatar_url !== undefined && oldAvatarUrl && oldAvatarUrl !== avatar_url) {
    cleanupAssets([oldAvatarUrl]);
  }

  const updated = await db`
    SELECT id, email, name, color, notification_type, email_verified, avatar_url FROM users WHERE id = ${userId}
  `;
  const u = updated[0];
  const gcal = await db`SELECT 1 FROM google_calendar_tokens WHERE user_id = ${userId}`;
  return json({
    id: u.id, email: u.email, name: u.name,
    color: u.color, notification_type: u.notification_type ?? "email",
    email_verified: u.email_verified ?? false,
    has_google_calendar: gcal.length > 0,
    avatar_url: u.avatar_url ?? null,
  });
}

export async function updateNotificationType(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  let body: { notification_type?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }
  if (body.notification_type !== "push" && body.notification_type !== "email") {
    return error("notification_type must be 'push' or 'email'");
  }
  await db`UPDATE users SET notification_type = ${body.notification_type} WHERE id = ${userId}`;
  return json({ notification_type: body.notification_type });
}

export async function googleAuth(ctx: RequestContext): Promise<Response> {
  console.log("[GoogleAuth] ── POST /auth/google ───────────────────────");
  let body: { idToken?: string; serverAuthCode?: string };
  try {
    body = await ctx.req.json();
  } catch {
    console.log("[GoogleAuth] ✗ failed to parse request body");
    return error("Invalid JSON body");
  }

  const { idToken, serverAuthCode } = body;
  console.log("[GoogleAuth] idToken present    :", !!idToken);
  console.log("[GoogleAuth] idToken prefix     :", idToken ? idToken.substring(0, 30) + "…" : "(none)");
  console.log("[GoogleAuth] serverAuthCode     :", serverAuthCode ?? "(none)");

  if (!idToken) return error("idToken is required");

  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const iosClientId = process.env.GOOGLE_IOS_CLIENT_ID;
  console.log("[GoogleAuth] GOOGLE_CLIENT_ID   :", clientId ? clientId.substring(0, 30) + "…" : "(missing!)");
  console.log("[GoogleAuth] GOOGLE_IOS_CLIENT_ID:", iosClientId ? iosClientId.substring(0, 30) + "…" : "(missing)");
  console.log("[GoogleAuth] GOOGLE_CLIENT_SECRET:", clientSecret ? "(set)" : "(missing!)");

  if (!clientId || !clientSecret) return error("Google OAuth not configured", 503);

  // Accept both Web and iOS client IDs as valid audiences —
  // iOS/macOS tokens have the iOS client ID as audience, not the Web client ID.
  const validAudiences = [clientId, ...(iosClientId ? [iosClientId] : [])];
  console.log("[GoogleAuth] validAudiences     :", validAudiences);

  const auth = new google.auth.OAuth2(clientId, clientSecret);
  let googleUser: { sub: string; email: string; name: string };
  try {
    console.log("[GoogleAuth] verifying ID token…");
    const ticket = await auth.verifyIdToken({ idToken, audience: validAudiences });
    const payload = ticket.getPayload();
    console.log("[GoogleAuth] token payload aud  :", payload?.aud);
    console.log("[GoogleAuth] token payload sub  :", payload?.sub ? payload.sub.substring(0, 10) + "…" : "(none)");
    console.log("[GoogleAuth] token payload email:", payload?.email);
    console.log("[GoogleAuth] token payload iss  :", payload?.iss);
    if (!payload?.sub || !payload?.email) {
      console.log("[GoogleAuth] ✗ payload missing sub or email");
      return error("Invalid Google token", 401);
    }
    googleUser = {
      sub: payload.sub,
      email: payload.email,
      name: payload.name ?? payload.email.split("@")[0],
    };
    console.log("[GoogleAuth] ✓ token verified for:", googleUser.email);
  } catch (e) {
    console.log("[GoogleAuth] ✗ verifyIdToken threw:", e instanceof Error ? e.message : String(e));
    return error("Invalid Google token", 401);
  }

  // Find existing user by Google ID or email
  console.log("[GoogleAuth] looking up user by google_id or email…");
  const existing = await db`SELECT * FROM users WHERE google_id = ${googleUser.sub} OR email = ${googleUser.email}`;
  console.log("[GoogleAuth] existing users found:", existing.length);
  let user: Record<string, unknown>;
  let isNew = false;

  if (existing.length > 0) {
    user = existing[0];
    console.log("[GoogleAuth] existing user id       :", user.id);
    console.log("[GoogleAuth] existing user google_id:", user.google_id ? "(set)" : "(null — password-only account)");
    if (!user.google_id) {
      // An account with this email already exists with a password — refuse silent
      // merge to prevent account takeover via a Google account with the same email.
      console.log("[GoogleAuth] ✗ refusing merge: password-only account with same email");
      return error("An account with this email already exists. Please sign in with your password.", 409);
    }
  } else {
    isNew = true;
    console.log("[GoogleAuth] no existing user — creating new account");
    const colors = ["#6C63FF", "#FF6584", "#43B89C", "#F5A623", "#4A90E2", "#E74C3C", "#2ECC71", "#9B59B6"];
    const countResult = await db`SELECT COUNT(*)::integer AS n FROM users`;
    const color = colors[Number(countResult[0].n) % colors.length];

    const created = await db`
      INSERT INTO users (email, name, color, google_id, email_verified)
      VALUES (${googleUser.email}, ${googleUser.name}, ${color}, ${googleUser.sub}, true)
      RETURNING *
    `;
    user = created[0];
    console.log("[GoogleAuth] ✓ new user created:", user.id);
  }

  const gcal = await db`SELECT 1 FROM google_calendar_tokens WHERE user_id = ${user.id}`;
  const token = await signToken({ sub: user.id as string, email: user.email as string, name: user.name as string });
  console.log("[GoogleAuth] ✓ returning JWT for", user.email, "| isNew:", isNew, "| has_google_calendar:", gcal.length > 0);
  return json({
    token,
    user: {
      id: user.id, email: user.email, name: user.name,
      color: user.color, notification_type: user.notification_type ?? "email",
      email_verified: true, has_google_calendar: gcal.length > 0,
    },
  }, isNew ? 201 : 200);
}

export async function forgotPassword(ctx: RequestContext): Promise<Response> {
  let body: { email?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { email } = body;
  if (!email) return error("email is required");

  // Always return 200 — don't reveal whether the email exists
  const users = await db`SELECT id, name, password_hash FROM users WHERE email = ${email}`;
  if (users.length === 0) return json({ message: "If that email exists, a reset link has been sent." });

  const user = users[0];
  // Google-only accounts have no password — can't reset what doesn't exist
  if (!user.password_hash) return json({ message: "If that email exists, a reset link has been sent." });

  const token = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

  await db`UPDATE users SET reset_token = ${token}, reset_expires_at = ${expiresAt} WHERE id = ${user.id}`;

  sendPasswordResetEmail(email, user.name, token).catch(console.error);

  return json({ message: "If that email exists, a reset link has been sent." });
}

export async function showResetPasswordForm(ctx: RequestContext): Promise<Response> {
  const { token } = ctx.params;
  const users = await db`
    SELECT id, reset_expires_at FROM users
    WHERE reset_token = ${token} AND reset_expires_at IS NOT NULL
  `;

  if (users.length === 0) {
    return new Response(resetErrorPage("This reset link is invalid or has already been used."), {
      status: 400, headers: { "Content-Type": "text/html" },
    });
  }

  if (new Date(users[0].reset_expires_at) < new Date()) {
    return new Response(resetErrorPage("This reset link has expired. Please request a new one in the app."), {
      status: 400, headers: { "Content-Type": "text/html" },
    });
  }

  return new Response(resetFormPage(token), {
    status: 200, headers: { "Content-Type": "text/html" },
  });
}

export async function submitResetPassword(ctx: RequestContext): Promise<Response> {
  const { token } = ctx.params;

  // Handle both JSON (from app) and form-encoded (from browser form)
  let newPassword: string | undefined;
  const contentType = ctx.req.headers.get("content-type") ?? "";

  if (contentType.includes("application/x-www-form-urlencoded")) {
    const text = await ctx.req.text();
    const params = new URLSearchParams(text);
    newPassword = params.get("password") ?? undefined;
  } else {
    try {
      const body = await ctx.req.json() as { password?: string };
      newPassword = body.password;
    } catch {
      return error("Invalid request body");
    }
  }

  if (!newPassword || newPassword.length < 6) {
    if (contentType.includes("application/x-www-form-urlencoded")) {
      return new Response(resetErrorPage("Password must be at least 6 characters."), {
        status: 400, headers: { "Content-Type": "text/html" },
      });
    }
    return error("Password must be at least 6 characters");
  }

  const users = await db`
    SELECT id, reset_expires_at FROM users
    WHERE reset_token = ${token} AND reset_expires_at IS NOT NULL
  `;

  if (users.length === 0) {
    if (contentType.includes("application/x-www-form-urlencoded")) {
      return new Response(resetErrorPage("This reset link is invalid or has already been used."), {
        status: 400, headers: { "Content-Type": "text/html" },
      });
    }
    return error("Invalid or expired reset token", 400);
  }

  if (new Date(users[0].reset_expires_at) < new Date()) {
    if (contentType.includes("application/x-www-form-urlencoded")) {
      return new Response(resetErrorPage("This reset link has expired. Please request a new one in the app."), {
        status: 400, headers: { "Content-Type": "text/html" },
      });
    }
    return error("Reset token has expired", 400);
  }

  const passwordHash = await Bun.password.hash(newPassword);
  await db`
    UPDATE users
    SET password_hash = ${passwordHash}, reset_token = NULL, reset_expires_at = NULL
    WHERE id = ${users[0].id}
  `;

  if (contentType.includes("application/x-www-form-urlencoded")) {
    return new Response(resetSuccessPage(), {
      status: 200, headers: { "Content-Type": "text/html" },
    });
  }
  return json({ message: "Password updated successfully" });
}

export async function deleteUser(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const rows = await db`SELECT avatar_url FROM users WHERE id = ${userId}`;
  if (rows.length > 0) cleanupAssets([rows[0].avatar_url as string | null]);
  await db`DELETE FROM users WHERE id = ${userId}`;
  return json({ message: "Account deleted" });
}

export async function disconnectGoogleCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  console.log("[gcal-debug] disconnectGoogleCalendar — userId=%s", userId);
  await db`DELETE FROM google_calendar_tokens WHERE user_id = ${userId}`;
  console.log("[gcal-debug] disconnectGoogleCalendar ✓ token deleted");
  return json({ message: "Google Calendar disconnected" });
}

export async function connectGoogleCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  console.log("[gcal-debug] connectGoogleCalendar — userId=%s", userId);
  try {
    const url = await generateCalendarConnectUrl(userId);
    console.log("[gcal-debug] connectGoogleCalendar ✓ returning OAuth URL to app");
    return json({ url });
  } catch (err) {
    console.error("[gcal-debug] connectGoogleCalendar ✗ generateCalendarConnectUrl threw:", err);
    return error("Google Calendar not configured", 503);
  }
}

export async function googleCalendarCallback(ctx: RequestContext): Promise<Response> {
  const urlObj = new URL(ctx.req.url);
  const code = urlObj.searchParams.get("code");
  const state = urlObj.searchParams.get("state");
  const errParam = urlObj.searchParams.get("error");
  console.log("[gcal-debug] googleCalendarCallback — state=%s error=%s code_present=%s",
    state ?? "(none)", errParam ?? "(none)", !!code);

  if (errParam || !code || !state) {
    console.warn("[gcal-debug] googleCalendarCallback ✗ missing params or Google error:", errParam);
    return new Response(calendarErrorPage(errParam ?? "Missing parameters"), {
      status: 400, headers: { "Content-Type": "text/html" },
    });
  }

  const success = await handleCalendarCallback(code, state);
  if (!success) {
    console.warn("[gcal-debug] googleCalendarCallback ✗ handleCalendarCallback returned false");
    return new Response(calendarErrorPage("Invalid or expired session. Please try again in the app."), {
      status: 400, headers: { "Content-Type": "text/html" },
    });
  }
  console.log("[gcal-debug] googleCalendarCallback ✓ returning success page");
  return new Response(calendarSuccessPage(), {
    status: 200, headers: { "Content-Type": "text/html" },
  });
}

// ── HTML pages ────────────────────────────────────────────────────────────────

function calendarSuccessPage(): string {
  return page(
    "Google Calendar connected ✅",
    "#2ECC71",
    `<h1 style="color:#1F1B16;font-size:26px;font-weight:800;margin:0 0 8px;">Calendar connected!</h1>
     <p style="color:#6B6357;font-size:15px;margin:0 0 24px;">Your Google Calendar is now linked to Milo. Return to the app and tap <strong>Done</strong>.</p>
     <span style="font-size:64px;">🎉</span>`,
  );
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function calendarErrorPage(message: string): string {
  return page(
    "Connection failed",
    "#E85535",
    `<h1 style="color:#1F1B16;font-size:24px;font-weight:800;margin:0 0 8px;">Connection failed</h1>
     <p style="color:#6B6357;font-size:15px;margin:0 0 24px;">${escapeHtml(message)}</p>
     <span style="font-size:64px;">😕</span>`,
  );
}

function successPage(name: string): string {
  return page(
    "Email verified ✅",
    "#2ECC71",
    `<h1 style="color:#1F1B16;font-size:26px;font-weight:800;margin:0 0 8px;">You're verified, ${name}!</h1>
     <p style="color:#6B6357;font-size:15px;margin:0 0 24px;">Your email address has been confirmed. You can close this tab and return to the app.</p>
     <span style="font-size:64px;">🎉</span>`,
  );
}

function errorPage(message: string): string {
  return page(
    "Verification failed",
    "#E85535",
    `<h1 style="color:#1F1B16;font-size:24px;font-weight:800;margin:0 0 8px;">Verification failed</h1>
     <p style="color:#6B6357;font-size:15px;margin:0 0 24px;">${message}</p>
     <span style="font-size:64px;">😕</span>`,
  );
}

function resetFormPage(token: string): string {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Reset password</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box}
body{margin:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px}
input{width:100%;padding:14px 16px;border:1.5px solid #EFE4D2;border-radius:14px;font-size:15px;outline:none;background:#FBF1E4;margin:8px 0 20px;font-family:inherit}
input:focus{border-color:#1F1B16}
button{width:100%;padding:14px;background:#1F1B16;color:#fff;border:none;border-radius:28px;font-size:15px;font-weight:700;cursor:pointer;font-family:inherit}
button:hover{opacity:0.85}
label{font-size:14px;font-weight:600;color:#1F1B16}
</style>
</head><body>
<div style="background:#fff;border-radius:24px;border:2px solid #EFE4D2;padding:40px;max-width:420px;width:100%;box-shadow:0 4px 0 #EFE4D2;">
  <div style="background:#1F1B16;width:48px;height:48px;border-radius:14px;margin:0 auto 20px;display:flex;align-items:center;justify-content:center;text-align:center;">
    <span style="color:white;font-size:20px;line-height:48px;">🔑</span>
  </div>
  <h1 style="color:#1F1B16;font-size:22px;font-weight:800;margin:0 0 6px;text-align:center;">Choose a new password</h1>
  <p style="color:#6B6357;font-size:14px;margin:0 0 24px;text-align:center;">Must be at least 6 characters.</p>
  <form method="POST" action="/auth/reset-password/${token}">
    <label for="pw">New password</label>
    <input id="pw" name="password" type="password" minlength="6" required autofocus placeholder="••••••••">
    <button type="submit">Set new password →</button>
  </form>
  <p style="color:#A39A8C;font-size:12px;margin:20px 0 0;text-align:center;">Milo</p>
</div>
</body></html>`;
}

function resetSuccessPage(): string {
  return page(
    "Password reset ✅",
    "#2ECC71",
    `<h1 style="color:#1F1B16;font-size:26px;font-weight:800;margin:0 0 8px;">Password updated!</h1>
     <p style="color:#6B6357;font-size:15px;margin:0 0 24px;">Your new password is set. You can close this tab and sign in to the app.</p>
     <span style="font-size:64px;">🎉</span>`,
  );
}

function resetErrorPage(message: string): string {
  return page(
    "Reset failed",
    "#E85535",
    `<h1 style="color:#1F1B16;font-size:24px;font-weight:800;margin:0 0 8px;">Reset failed</h1>
     <p style="color:#6B6357;font-size:15px;margin:0 0 24px;">${message}</p>
     <span style="font-size:64px;">😕</span>`,
  );
}

function page(title: string, accent: string, body: string): string {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><title>${title}</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>*{box-sizing:border-box}body{margin:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px}</style>
</head><body>
<div style="background:#fff;border-radius:24px;border:2px solid #EFE4D2;padding:48px 40px;max-width:440px;width:100%;text-align:center;box-shadow:0 4px 0 #EFE4D2;">
  <div style="background:${accent};width:56px;height:56px;border-radius:16px;margin:0 auto 24px;display:flex;align-items:center;justify-content:center;">
    <span style="color:white;font-size:24px;">📅</span>
  </div>
  ${body}
  <p style="color:#A39A8C;font-size:12px;margin:24px 0 0;">Milo</p>
</div>
</body></html>`;
}
