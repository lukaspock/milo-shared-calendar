import { google } from "googleapis";
import db from "../db/client";
import { encrypt, decrypt } from "./crypto";

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const APP_URL = process.env.APP_URL ?? "https://api.milocalendar.tech";


function makeAuth(accessToken?: string | null, refreshToken?: string | null) {
  const auth = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET);
  if (accessToken || refreshToken) {
    auth.setCredentials({ access_token: accessToken, refresh_token: refreshToken });
  }
  return auth;
}

// ── Web OAuth flow for Calendar connection ────────────────────────────────────

const pendingCalendarConnects = new Map<string, { userId: string; expiresAt: number }>();

setInterval(() => {
  const now = Date.now();
  for (const [key, val] of pendingCalendarConnects) {
    if (val.expiresAt < now) pendingCalendarConnects.delete(key);
  }
}, 60_000);

export function generateCalendarConnectUrl(userId: string): string {
  if (!CLIENT_ID) throw new Error("Google OAuth not configured");
  const state = crypto.randomUUID();
  pendingCalendarConnects.set(state, { userId, expiresAt: Date.now() + 15 * 60_000 });
  const redirectUri = `${APP_URL}/auth/google-calendar/callback`;
  const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  url.searchParams.set("client_id", CLIENT_ID);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", "https://www.googleapis.com/auth/calendar.events");
  url.searchParams.set("access_type", "offline");
  url.searchParams.set("prompt", "consent");
  url.searchParams.set("state", state);
  return url.toString();
}

export async function handleCalendarCallback(code: string, state: string): Promise<boolean> {
  const pending = pendingCalendarConnects.get(state);
  if (!pending || pending.expiresAt < Date.now()) return false;
  pendingCalendarConnects.delete(state);
  if (!CLIENT_ID || !CLIENT_SECRET) return false;
  const redirectUri = `${APP_URL}/auth/google-calendar/callback`;
  try {
    const auth = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, redirectUri);
    const { tokens } = await auth.getToken(code);
    if (!tokens.access_token || !tokens.refresh_token) return false;
    const expiry = tokens.expiry_date ? new Date(tokens.expiry_date) : new Date(Date.now() + 3_600_000);
    const encAccess = await encrypt(tokens.access_token);
    const encRefresh = await encrypt(tokens.refresh_token);
    await db`
      INSERT INTO google_calendar_tokens (user_id, access_token, refresh_token, expiry)
      VALUES (${pending.userId}, ${encAccess}, ${encRefresh}, ${expiry})
      ON CONFLICT (user_id) DO UPDATE SET
        access_token = ${encAccess},
        refresh_token = ${encRefresh},
        expiry = ${expiry}
    `;
    return true;
  } catch (err) {
    console.error("[gcal] handleCalendarCallback failed:", err);
    return false;
  }
}

async function getTokens(userId: string): Promise<{ access_token: string; refresh_token: string } | null> {
  const rows = await db`SELECT access_token, refresh_token FROM google_calendar_tokens WHERE user_id = ${userId}`;
  if (rows.length === 0) return null;
  const access_token = await decrypt(rows[0].access_token as string);
  const refresh_token = await decrypt(rows[0].refresh_token as string);
  return { access_token, refresh_token };
}

async function createGoogleEvent(params: {
  userId: string;
  eventId: string;
  title: string;
  description?: string | null;
  startTime: Date;
  endTime: Date;
}): Promise<void> {
  const tokens = await getTokens(params.userId);
  if (!tokens) return;
  try {
    const cal = google.calendar({ version: "v3", auth: makeAuth(tokens.access_token, tokens.refresh_token) });
    const res = await cal.events.insert({
      calendarId: "primary",
      requestBody: {
        summary: params.title,
        description: params.description ?? undefined,
        start: { dateTime: params.startTime.toISOString() },
        end: { dateTime: params.endTime.toISOString() },
      },
    });
    const googleEventId = res.data.id;
    if (googleEventId) {
      await db`
        INSERT INTO google_event_ids (event_id, user_id, google_event_id)
        VALUES (${params.eventId}, ${params.userId}, ${googleEventId})
        ON CONFLICT (event_id, user_id) DO UPDATE SET google_event_id = ${googleEventId}
      `;
    }
  } catch (err) {
    console.error(`[gcal] createGoogleEvent failed for user ${params.userId}:`, err);
  }
}

export async function syncEventCreated(params: {
  calendarId: string;
  eventId: string;
  title: string;
  description?: string | null;
  startTime: Date;
  endTime: Date;
}): Promise<void> {
  const members = await db`
    SELECT cm.user_id
    FROM calendar_members cm
    INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
    WHERE cm.calendar_id = ${params.calendarId}
  `;
  for (const m of members as Record<string, unknown>[]) {
    await createGoogleEvent({ userId: m.user_id as string, ...params });
  }
}

export async function syncEventUpdated(params: {
  eventId: string;
  title: string;
  description?: string | null;
  startTime: Date;
  endTime: Date;
}): Promise<void> {
  const rows = await db`
    SELECT gei.google_event_id, gct.access_token, gct.refresh_token, gei.user_id
    FROM google_event_ids gei
    INNER JOIN google_calendar_tokens gct ON gct.user_id = gei.user_id
    WHERE gei.event_id = ${params.eventId}
  `;
  for (const row of rows as Record<string, unknown>[]) {
    try {
      const access = await decrypt(row.access_token as string);
      const refresh = await decrypt(row.refresh_token as string);
      const cal = google.calendar({ version: "v3", auth: makeAuth(access, refresh) });
      await cal.events.update({
        calendarId: "primary",
        eventId: row.google_event_id as string,
        requestBody: {
          summary: params.title,
          description: params.description ?? undefined,
          start: { dateTime: params.startTime.toISOString() },
          end: { dateTime: params.endTime.toISOString() },
        },
      });
    } catch (err) {
      console.error(`[gcal] syncEventUpdated failed for user ${row.user_id}:`, err);
    }
  }
}

export async function syncEventDeleted(eventId: string): Promise<void> {
  const rows = await db`
    SELECT gei.google_event_id, gct.access_token, gct.refresh_token, gei.user_id
    FROM google_event_ids gei
    INNER JOIN google_calendar_tokens gct ON gct.user_id = gei.user_id
    WHERE gei.event_id = ${eventId}
  `;
  for (const row of rows as Record<string, unknown>[]) {
    try {
      const access = await decrypt(row.access_token as string);
      const refresh = await decrypt(row.refresh_token as string);
      const cal = google.calendar({ version: "v3", auth: makeAuth(access, refresh) });
      await cal.events.delete({
        calendarId: "primary",
        eventId: row.google_event_id as string,
      });
    } catch (err) {
      console.error(`[gcal] syncEventDeleted failed for user ${row.user_id}:`, err);
    }
  }
}
