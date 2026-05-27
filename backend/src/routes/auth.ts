import db from "../db/client";
import { signToken } from "../middleware/auth.middleware";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { sendVerificationEmail } from "../services/email";

export async function register(ctx: RequestContext): Promise<Response> {
  let body: { email?: string; password?: string; name?: string };
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

  const existing = await db`SELECT id FROM users WHERE email = ${email}`;
  if (existing.length > 0) {
    return error("Email already in use", 409);
  }

  const passwordHash = await Bun.password.hash(password);

  const colors = ["#6C63FF", "#FF6584", "#43B89C", "#F5A623", "#4A90E2", "#E74C3C", "#2ECC71", "#9B59B6"];
  const countResult = await db`SELECT COUNT(*) AS count FROM users`;
  const idx = Number(countResult[0].count) % colors.length;
  const color = colors[idx];

  const verificationToken = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  const users = await db`
    INSERT INTO users (email, password_hash, name, color, verification_token, verification_expires_at)
    VALUES (${email}, ${passwordHash}, ${name}, ${color}, ${verificationToken}, ${expiresAt})
    RETURNING id, email, name, color, email_verified, created_at
  `;
  const user = users[0];

  // Fire-and-forget — don't block the response
  sendVerificationEmail(email, name, verificationToken).catch(console.error);

  const token = await signToken({ sub: user.id, email: user.email, name: user.name });

  return json({
    token,
    user: { id: user.id, email: user.email, name: user.name, color: user.color, email_verified: false },
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
      email_verified: user.email_verified ?? false,
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
    SELECT id, email, name, color, email_verified FROM users WHERE id = ${userId}
  `;
  if (users.length === 0) return error("User not found", 404);
  const user = users[0];
  return json({
    id: user.id, email: user.email, name: user.name,
    color: user.color, email_verified: user.email_verified ?? false,
  });
}

export async function deleteUser(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  await db`DELETE FROM users WHERE id = ${userId}`;
  return json({ message: "Account deleted" });
}

// ── HTML pages for browser-based verification ─────────────────────────────────

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
  <p style="color:#A39A8C;font-size:12px;margin:24px 0 0;">SharedCal</p>
</div>
</body></html>`;
}
