import { google } from "googleapis";

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const GOOGLE_REFRESH_TOKEN = process.env.GOOGLE_REFRESH_TOKEN;
const FROM = process.env.FROM_EMAIL ?? "lukaspock.dev@gmail.com";
const APP_URL = process.env.APP_URL ?? "https://api.milocalendar.tech";

function getGmailClient() {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET || !GOOGLE_REFRESH_TOKEN) return null;
  const auth = new google.auth.OAuth2(GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET);
  auth.setCredentials({ refresh_token: GOOGLE_REFRESH_TOKEN });
  return google.gmail({ version: "v1", auth });
}

async function send(to: string, subject: string, html: string): Promise<void> {
  const gmail = getGmailClient();
  if (!gmail) {
    console.log(`[email] no Google OAuth2 config — skipping "${subject}" to ${to}`);
    return;
  }
  const raw = Buffer.from(
    `From: SharedCal <${FROM}>\r\nTo: ${to}\r\nSubject: ${subject}\r\nContent-Type: text/html; charset=utf-8\r\n\r\n${html}`
  ).toString("base64url");
  try {
    await gmail.users.messages.send({ userId: "me", requestBody: { raw } });
    console.log(`[email] sent "${subject}" to ${to}`);
  } catch (err) {
    console.error("[email] send failed:", err);
  }
}

function base(content: string): string {
  return `<!DOCTYPE html><html><body style="margin:0;padding:0;background:#FFF8F0;font-family:'Helvetica Neue',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:40px 16px;">
<table width="520" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:20px;border:1.5px solid #EFE4D2;overflow:hidden;">
<tr><td style="background:#1F1B16;padding:24px 32px;">
  <span style="color:#fff;font-size:20px;font-weight:700;letter-spacing:-0.5px;">📅 SharedCal</span>
</td></tr>
<tr><td style="padding:32px;">${content}</td></tr>
<tr><td style="padding:16px 32px;background:#FBF1E4;border-top:1.5px solid #EFE4D2;">
  <span style="color:#A39A8C;font-size:12px;">SharedCal — shared calendars made simple</span>
</td></tr>
</table>
</td></tr></table></body></html>`;
}

function btn(href: string, label: string): string {
  return `<a href="${href}" style="display:inline-block;background:#1F1B16;color:#fff;padding:14px 28px;border-radius:28px;text-decoration:none;font-size:14px;font-weight:700;margin:20px 0;">${label}</a>`;
}

export async function sendVerificationEmail(email: string, name: string, token: string): Promise<void> {
  const link = `${APP_URL}/auth/verify/${token}`;
  const html = base(`
    <h2 style="color:#1F1B16;font-size:22px;font-weight:800;margin:0 0 8px;">Hi ${name}! 👋</h2>
    <p style="color:#6B6357;font-size:15px;line-height:1.6;margin:0 0 4px;">
      Thanks for signing up. Please verify your email address to get started.
    </p>
    ${btn(link, "Verify email address")}
    <p style="color:#A39A8C;font-size:13px;margin:0;">
      Or copy this link:<br>
      <a href="${link}" style="color:#1F1B16;word-break:break-all;">${link}</a>
    </p>
    <p style="color:#A39A8C;font-size:12px;margin:20px 0 0;">This link expires in 24 hours.</p>
  `);
  await send(email, "Verify your SharedCal email address", html);
}

export async function sendPasswordResetEmail(email: string, name: string, token: string): Promise<void> {
  const link = `${APP_URL}/auth/reset-password/${token}`;
  const html = base(`
    <h2 style="color:#1F1B16;font-size:22px;font-weight:800;margin:0 0 8px;">Reset your password 🔑</h2>
    <p style="color:#6B6357;font-size:15px;line-height:1.6;margin:0 0 4px;">
      Hi ${name}, we received a request to reset your SharedCal password.
      Tap the button below to choose a new one.
    </p>
    ${btn(link, "Reset password")}
    <p style="color:#A39A8C;font-size:13px;margin:0;">
      Or copy this link:<br>
      <a href="${link}" style="color:#1F1B16;word-break:break-all;">${link}</a>
    </p>
    <p style="color:#A39A8C;font-size:12px;margin:20px 0 0;">
      This link expires in 1 hour. If you didn't request a reset, you can safely ignore this email.
    </p>
  `);
  await send(email, "Reset your SharedCal password", html);
}

export async function sendReminderEmail(params: {
  memberEmails: string[];
  eventTitle: string;
  calendarName: string;
  startTime: Date;
}): Promise<void> {
  const { memberEmails, eventTitle, calendarName, startTime } = params;
  if (memberEmails.length === 0) return;

  const dateStr = startTime.toLocaleDateString("de-AT", {
    weekday: "long", year: "numeric", month: "long", day: "numeric",
  });
  const timeStr = startTime.toLocaleTimeString("de-AT", { hour: "2-digit", minute: "2-digit" });

  const html = base(`
    <h2 style="color:#1F1B16;font-size:22px;font-weight:800;margin:0 0 16px;">⏰ Event in 30 minutes</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#FBF1E4;border-radius:14px;border:1.5px solid #EFE4D2;">
      <tr><td style="padding:20px;">
        <p style="margin:0 0 8px;font-size:18px;font-weight:700;color:#1F1B16;">${eventTitle}</p>
        <p style="margin:0 0 4px;color:#6B6357;font-size:14px;">📅 ${dateStr}</p>
        <p style="margin:0 0 4px;color:#6B6357;font-size:14px;">⏰ ${timeStr}</p>
        <p style="margin:8px 0 0;color:#A39A8C;font-size:13px;">in ${calendarName}</p>
      </td></tr>
    </table>
  `);

  for (const email of memberEmails) {
    await send(email, `Reminder: ${eventTitle} starts in 30 min`, html);
  }
}

export async function sendEventNotification(params: {
  memberEmails: string[];
  eventTitle: string;
  calendarName: string;
  startTime: Date;
  creatorName: string;
}): Promise<void> {
  const { memberEmails, eventTitle, calendarName, startTime, creatorName } = params;
  if (memberEmails.length === 0) return;

  const dateStr = startTime.toLocaleDateString("de-AT", {
    weekday: "long", year: "numeric", month: "long", day: "numeric",
  });
  const timeStr = startTime.toLocaleTimeString("de-AT", { hour: "2-digit", minute: "2-digit" });

  const html = base(`
    <h2 style="color:#1F1B16;font-size:22px;font-weight:800;margin:0 0 16px;">New event in ${calendarName} 🗓️</h2>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#FBF1E4;border-radius:14px;border:1.5px solid #EFE4D2;">
      <tr><td style="padding:20px;">
        <p style="margin:0 0 8px;font-size:18px;font-weight:700;color:#1F1B16;">${eventTitle}</p>
        <p style="margin:0 0 4px;color:#6B6357;font-size:14px;">📅 ${dateStr}</p>
        <p style="margin:0 0 4px;color:#6B6357;font-size:14px;">⏰ ${timeStr}</p>
        <p style="margin:8px 0 0;color:#A39A8C;font-size:13px;">Added by ${creatorName}</p>
      </td></tr>
    </table>
  `);

  for (const email of memberEmails) {
    await send(email, `New event: ${eventTitle} — ${calendarName}`, html);
  }
}

export async function sendPollConfirmedNotification(params: {
  memberEmails: string[];
  eventTitle: string;
  calendarName: string;
  startTime: Date;
}): Promise<void> {
  const { memberEmails, eventTitle, calendarName, startTime } = params;
  if (memberEmails.length === 0) return;

  const dateStr = startTime.toLocaleDateString("de-AT", {
    weekday: "long", year: "numeric", month: "long", day: "numeric",
  });
  const timeStr = startTime.toLocaleTimeString("de-AT", { hour: "2-digit", minute: "2-digit" });

  const html = base(`
    <h2 style="color:#1F1B16;font-size:22px;font-weight:800;margin:0 0 16px;">Poll confirmed in ${calendarName} ✅</h2>
    <p style="color:#6B6357;font-size:15px;line-height:1.6;margin:0 0 16px;">
      A poll result has been confirmed as a new event:
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="background:#FBF1E4;border-radius:14px;border:1.5px solid #EFE4D2;">
      <tr><td style="padding:20px;">
        <p style="margin:0 0 8px;font-size:18px;font-weight:700;color:#1F1B16;">${eventTitle}</p>
        <p style="margin:0 0 4px;color:#6B6357;font-size:14px;">📅 ${dateStr}</p>
        <p style="margin:0;color:#6B6357;font-size:14px;">⏰ ${timeStr}</p>
      </td></tr>
    </table>
  `);

  for (const email of memberEmails) {
    await send(email, `Confirmed: ${eventTitle} — ${calendarName}`, html);
  }
}
