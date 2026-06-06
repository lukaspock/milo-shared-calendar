import { google } from "googleapis";
import db from "../db/client";
import { encrypt, decrypt } from "./crypto";
import { broadcastToCalendar } from "../ws/websocket";

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const APP_URL = process.env.APP_URL ?? "https://api.milocalendar.tech";


function makeAuth(
  accessToken?: string | null,
  refreshToken?: string | null,
  expiryDate?: Date | null,
) {
  const auth = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET);
  if (accessToken || refreshToken) {
    auth.setCredentials({
      access_token: accessToken,
      refresh_token: refreshToken,
      // Telling the library the expiry date lets it proactively refresh the
      // access token before it expires, instead of sending a stale token and
      // waiting for a 401.
      expiry_date: expiryDate?.getTime() ?? undefined,
    });
  }
  return auth;
}

// ── Web OAuth flow for Calendar connection ────────────────────────────────────

export async function generateCalendarConnectUrl(userId: string): Promise<string> {
  if (!CLIENT_ID) throw new Error("Google OAuth not configured");
  const state = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 15 * 60_000);
  await db`
    INSERT INTO pending_calendar_connects (state, user_id, expires_at)
    VALUES (${state}, ${userId}, ${expiresAt})
  `;
  // Clean up expired rows opportunistically
  db`DELETE FROM pending_calendar_connects WHERE expires_at < now()`.catch(() => {});
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
  const rows = await db`
    DELETE FROM pending_calendar_connects
    WHERE state = ${state} AND expires_at > now()
    RETURNING user_id
  `;
  if (rows.length === 0) return false;
  const pending = { userId: rows[0].user_id as string };
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

    // Pre-populate the cache for all calendars this user belongs to so the
    // first app load shows events immediately (no manual double-refresh needed).
    const now = new Date();
    const startDate = new Date(now.getFullYear() - 1, now.getMonth(), 1);
    const endDate = new Date(now.getFullYear() + 1, now.getMonth() + 1, 0);
    db`SELECT calendar_id FROM calendar_members WHERE user_id = ${pending.userId}`
      .then(async (rows) => {
        for (const row of rows as Record<string, unknown>[]) {
          await fetchAndCacheGoogleEventsForCalendar({
            calendarId: row.calendar_id as string,
            startDate,
            endDate,
          });
        }
      })
      .catch((e: unknown) => console.error("[gcal] post-connect pre-fetch failed:", e));

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
        extendedProperties: {
          private: { sharedcal_origin: "true" },
        },
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
    console.error(`[gcal] createGoogleEvent failed for user ${params.userId}:`, err); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
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
      console.error(`[gcal] syncEventUpdated failed for user ${row.user_id}:`, err); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
    }
  }
}

type ImportedByEntry = { user_id: string; name: string; color: string };

function mergeImportedBy(
  existing: ImportedByEntry[],
  toAdd: ImportedByEntry[]
): ImportedByEntry[] {
  const result = [...existing];
  for (const entry of toAdd) {
    if (!result.some((e) => e.user_id === entry.user_id)) result.push(entry);
  }
  return result;
}

export async function fetchAndCacheGoogleEventsForCalendar(params: {
  calendarId: string;
  startDate: Date;
  endDate: Date;
}): Promise<void> {
  const { calendarId, startDate, endDate } = params;

  // Members who have connected Google Calendar, joined with user profile
  const memberRows = await db`
    SELECT cm.user_id, u.name, u.color, gct.access_token, gct.refresh_token, gct.expiry
    FROM calendar_members cm
    INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
    INNER JOIN users u ON u.id = cm.user_id
    WHERE cm.calendar_id = ${calendarId}
  `;
  if (memberRows.length === 0) return;

  // Build set of Google event IDs already written by SharedCal (layer B filter)
  const ownedGoogleIds = await db`
    SELECT gei.google_event_id
    FROM google_event_ids gei
    INNER JOIN events e ON e.id = gei.event_id
    WHERE e.calendar_id = ${calendarId}
  `;
  const ownedIdSet = new Set(ownedGoogleIds.map((r: Record<string, unknown>) => r.google_event_id as string));

  // Preload existing imported_by values to enable in-memory merging
  const existingRows = await db`
    SELECT ical_uid, imported_by FROM imported_gcal_events WHERE calendar_id = ${calendarId}
  `;
  const importedByMap = new Map<string, ImportedByEntry[]>();
  for (const row of existingRows as Record<string, unknown>[]) {
    importedByMap.set(row.ical_uid as string, row.imported_by as ImportedByEntry[]);
  }

  for (const member of memberRows as Record<string, unknown>[]) {
    try {
      const access = await decrypt(member.access_token as string);
      const refresh = await decrypt(member.refresh_token as string);
      const expiry = member.expiry ? new Date(member.expiry as string) : null;
      const auth = makeAuth(access, refresh, expiry);

      // When the library auto-refreshes the access token, persist the new token
      // so subsequent imports don't have to refresh again from scratch.
      auth.on("tokens", async (newTokens) => {
        try {
          const updates: Record<string, unknown> = {};
          if (newTokens.access_token) {
            updates.access_token = await encrypt(newTokens.access_token);
          }
          if (newTokens.refresh_token) {
            updates.refresh_token = await encrypt(newTokens.refresh_token);
          }
          const newExpiry = newTokens.expiry_date
            ? new Date(newTokens.expiry_date)
            : new Date(Date.now() + 3_600_000);
          if (updates.access_token && updates.refresh_token) {
            await db`UPDATE google_calendar_tokens SET access_token = ${updates.access_token as string}, refresh_token = ${updates.refresh_token as string}, expiry = ${newExpiry} WHERE user_id = ${member.user_id}`;
          } else if (updates.access_token) {
            await db`UPDATE google_calendar_tokens SET access_token = ${updates.access_token as string}, expiry = ${newExpiry} WHERE user_id = ${member.user_id}`;
          }
          console.log(`[gcal import] refreshed token persisted for user ${member.user_id}`);
        } catch (e) {
          console.error(`[gcal import] failed to persist refreshed token for user ${member.user_id}:`, e); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
        }
      });

      const cal = google.calendar({ version: "v3", auth });

      const res = await cal.events.list({
        calendarId: "primary",
        timeMin: startDate.toISOString(),
        timeMax: endDate.toISOString(),
        singleEvents: true,
        maxResults: 250,
        // TODO: implement pagination for users with >250 events in range
      });

      const memberEntry: ImportedByEntry = {
        user_id: member.user_id as string,
        name: member.name as string,
        color: member.color as string,
      };

      for (const event of res.data.items ?? []) {
        // Layer A: skip events SharedCal created (tagged via extendedProperties)
        if (event.extendedProperties?.private?.sharedcal_origin === "true") continue;
        // Layer B: skip events whose Google ID is in our google_event_ids table
        if (event.id && ownedIdSet.has(event.id)) continue;
        if (event.status === "cancelled") continue;
        if (!event.start?.dateTime && !event.start?.date) continue;
        // Both iCalUID and id must be present to construct a stable dedup key
        if (!event.iCalUID && !event.id) continue;

        const icalUid = event.iCalUID || event.id!;

        // Normalize all-day events (start.date = "2025-06-15", no dateTime)
        let startTime: string;
        let endTime: string;
        if (event.start?.dateTime) {
          startTime = event.start.dateTime;
          endTime = event.end?.dateTime ?? event.start.dateTime;
        } else {
          startTime = `${event.start!.date}T00:00:00Z`;
          // Google Calendar's end.date is *exclusive* (next day for single-day events).
          // Subtract one day to get the inclusive end date so the event only spans
          // the correct number of calendar days.
          const rawEnd = event.end?.date ?? event.start!.date;
          const endDateObj = new Date(rawEnd + "T00:00:00Z");
          endDateObj.setUTCDate(endDateObj.getUTCDate() - 1);
          endTime = `${endDateObj.toISOString().substring(0, 10)}T23:59:59Z`;
        }

        const existing = importedByMap.get(icalUid) ?? [];
        const merged = mergeImportedBy(existing, [memberEntry]);
        importedByMap.set(icalUid, merged);

        await db`
          INSERT INTO imported_gcal_events
            (calendar_id, ical_uid, title, start_time, end_time, description, google_event_id, imported_by)
          VALUES
            (${calendarId}, ${icalUid}, ${event.summary ?? "(no title)"},
             ${startTime}, ${endTime}, ${event.description ?? null},
             ${event.id ?? null}, ${JSON.stringify(merged)})
          ON CONFLICT (calendar_id, ical_uid) DO UPDATE SET
            title          = EXCLUDED.title,
            start_time     = EXCLUDED.start_time,
            end_time       = EXCLUDED.end_time,
            description    = EXCLUDED.description,
            google_event_id = EXCLUDED.google_event_id,
            imported_by    = EXCLUDED.imported_by,
            last_synced_at = now()
        `;
      }
    } catch (err: unknown) {
      const status = (err as { status?: number; code?: number })?.status
        ?? (err as { status?: number; code?: number })?.code;
      if (status === 401 || status === 403) {
        console.warn(`[gcal import] revoking token for user ${member.user_id}: HTTP ${status}`);
        await db`DELETE FROM google_calendar_tokens WHERE user_id = ${member.user_id}`;
      } else {
        console.error(`[gcal import] member ${member.user_id} failed:`, err); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
      }
    }
  }

  // Notify all connected clients that the Google Calendar cache was updated
  // so the Flutter app refreshes automatically without a manual pull.
  broadcastToCalendar(calendarId, { type: "gcal_synced", calendar_id: calendarId });
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
      console.error(`[gcal] syncEventDeleted failed for user ${row.user_id}:`, err); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
    }
  }
}
