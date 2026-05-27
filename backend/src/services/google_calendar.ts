import { google } from "googleapis";
import db from "../db/client";

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;

function makeAuth(accessToken?: string | null, refreshToken?: string | null) {
  const auth = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, "postmessage");
  if (accessToken || refreshToken) {
    auth.setCredentials({ access_token: accessToken, refresh_token: refreshToken });
  }
  return auth;
}

export async function exchangeServerAuthCode(code: string): Promise<{
  access_token: string;
  refresh_token: string;
  expiry: Date;
} | null> {
  if (!CLIENT_ID || !CLIENT_SECRET) return null;
  try {
    const { tokens } = await makeAuth().getToken(code);
    if (!tokens.access_token) return null;
    return {
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token ?? "",
      expiry: tokens.expiry_date ? new Date(tokens.expiry_date) : new Date(Date.now() + 3_600_000),
    };
  } catch (err) {
    console.error("[gcal] exchangeServerAuthCode failed:", err);
    return null;
  }
}

async function getTokens(userId: string): Promise<{ access_token: string; refresh_token: string } | null> {
  const rows = await db`SELECT access_token, refresh_token FROM google_calendar_tokens WHERE user_id = ${userId}`;
  if (rows.length === 0) return null;
  return { access_token: rows[0].access_token as string, refresh_token: rows[0].refresh_token as string };
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
      const cal = google.calendar({ version: "v3", auth: makeAuth(row.access_token as string, row.refresh_token as string) });
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
      const cal = google.calendar({ version: "v3", auth: makeAuth(row.access_token as string, row.refresh_token as string) });
      await cal.events.delete({
        calendarId: "primary",
        eventId: row.google_event_id as string,
      });
    } catch (err) {
      console.error(`[gcal] syncEventDeleted failed for user ${row.user_id}:`, err);
    }
  }
}
