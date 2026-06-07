import { google } from "googleapis";
import db from "../db/client";
import { encrypt, decrypt } from "./crypto";
import { broadcastToCalendar } from "../ws/websocket";

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const APP_URL = process.env.APP_URL ?? "https://api.milocalendar.tech";

const D = (...args: unknown[]) => console.log("[gcal-debug]", ...args);

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
      expiry_date: expiryDate?.getTime() ?? undefined,
    });
  }
  return auth;
}

// ── Web OAuth flow for Calendar connection ────────────────────────────────────

export async function generateCalendarConnectUrl(userId: string): Promise<string> {
  D(`generateCalendarConnectUrl — userId=${userId}`);
  D(`  CLIENT_ID present: ${!!CLIENT_ID}`);
  D(`  APP_URL: ${APP_URL}`);
  if (!CLIENT_ID) throw new Error("Google OAuth not configured");
  const state = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 15 * 60_000);
  D(`  inserting pending_calendar_connects state=${state} expiresAt=${expiresAt.toISOString()}`);
  await db`
    INSERT INTO pending_calendar_connects (state, user_id, expires_at)
    VALUES (${state}, ${userId}, ${expiresAt})
  `;
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
  D(`  redirect_uri: ${redirectUri}`);
  D(`  generated OAuth URL (truncated): ${url.toString().substring(0, 120)}…`);
  return url.toString();
}

export async function handleCalendarCallback(code: string, state: string): Promise<boolean> {
  D(`handleCalendarCallback — state=${state} code_len=${code.length}`);
  const rows = await db`
    DELETE FROM pending_calendar_connects
    WHERE state = ${state} AND expires_at > now()
    RETURNING user_id
  `;
  D(`  pending_calendar_connects lookup → ${rows.length} row(s)`);
  if (rows.length === 0) {
    D(`  ✗ no matching pending row — state invalid or expired`);
    return false;
  }
  const pending = { userId: rows[0].user_id as string };
  D(`  userId=${pending.userId}`);
  if (!CLIENT_ID || !CLIENT_SECRET) {
    D(`  ✗ CLIENT_ID or CLIENT_SECRET missing`);
    return false;
  }
  const redirectUri = `${APP_URL}/auth/google-calendar/callback`;
  D(`  exchanging code with redirect_uri=${redirectUri}`);
  try {
    const auth = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, redirectUri);
    const { tokens } = await auth.getToken(code);
    D(`  token exchange response:`);
    D(`    access_token present:  ${!!tokens.access_token}`);
    D(`    refresh_token present: ${!!tokens.refresh_token}`);
    D(`    expiry_date:           ${tokens.expiry_date ?? "(none)"}`);
    D(`    token_type:            ${tokens.token_type ?? "(none)"}`);
    D(`    scope:                 ${tokens.scope ?? "(none)"}`);
    if (!tokens.access_token || !tokens.refresh_token) {
      D(`  ✗ missing access_token or refresh_token — aborting`);
      return false;
    }
    const expiry = tokens.expiry_date ? new Date(tokens.expiry_date) : new Date(Date.now() + 3_600_000);
    D(`  encrypting tokens…`);
    const encAccess = await encrypt(tokens.access_token);
    const encRefresh = await encrypt(tokens.refresh_token);
    D(`  upserting google_calendar_tokens for userId=${pending.userId}`);
    await db`
      INSERT INTO google_calendar_tokens (user_id, access_token, refresh_token, expiry)
      VALUES (${pending.userId}, ${encAccess}, ${encRefresh}, ${expiry})
      ON CONFLICT (user_id) DO UPDATE SET
        access_token = ${encAccess},
        refresh_token = ${encRefresh},
        expiry = ${expiry}
    `;
    D(`  ✓ tokens stored, expiry=${expiry.toISOString()}`);

    // Pre-populate calendar cache for all calendars this user belongs to
    D(`  looking up calendars for userId=${pending.userId}…`);
    const now = new Date();
    const startDate = new Date(now.getFullYear() - 1, now.getMonth(), 1);
    const endDate = new Date(now.getFullYear() + 1, now.getMonth() + 1, 0);
    db`
      SELECT cm.calendar_id FROM calendar_members cm
      INNER JOIN calendars c ON c.id = cm.calendar_id
      WHERE cm.user_id = ${pending.userId}
    `
      .then(async (rows) => {
        D(`  pre-fetch: found ${rows.length} calendar(s) — starting background import`);
        for (const row of rows as Record<string, unknown>[]) {
          D(`  pre-fetch: importing calendarId=${row.calendar_id}`);
          await fetchAndCacheGoogleEventsForCalendar({
            calendarId: row.calendar_id as string,
            startDate,
            endDate,
          });
          D(`  pre-fetch: done calendarId=${row.calendar_id}`);
        }
        D(`  pre-fetch: all calendars done`);
      })
      .catch((e: unknown) => {
        D(`  pre-fetch FAILED:`, e);
        console.error("[gcal] post-connect pre-fetch failed:", e);
      });

    return true;
  } catch (err) {
    D(`  ✗ handleCalendarCallback threw:`, err);
    console.error("[gcal] handleCalendarCallback failed:", err);
    return false;
  }
}

async function getTokens(userId: string): Promise<{ access_token: string; refresh_token: string } | null> {
  D(`getTokens — userId=${userId}`);
  const rows = await db`SELECT access_token, refresh_token FROM google_calendar_tokens WHERE user_id = ${userId}`;
  if (rows.length === 0) {
    D(`  no tokens found for userId=${userId}`);
    return null;
  }
  D(`  tokens found, decrypting…`);
  const access_token = await decrypt(rows[0].access_token as string);
  const refresh_token = await decrypt(rows[0].refresh_token as string);
  D(`  ✓ tokens decrypted`);
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
  D(`createGoogleEvent — userId=${params.userId} eventId=${params.eventId} title="${params.title}"`);
  const tokens = await getTokens(params.userId);
  if (!tokens) {
    D(`  no tokens for userId=${params.userId} — skipping`);
    return;
  }
  try {
    const cal = google.calendar({ version: "v3", auth: makeAuth(tokens.access_token, tokens.refresh_token) });
    D(`  inserting event to Google Calendar primary…`);
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
    D(`  ✓ Google event created — googleEventId=${googleEventId} status=${res.status}`);
    if (googleEventId) {
      await db`
        INSERT INTO google_event_ids (event_id, user_id, google_event_id)
        VALUES (${params.eventId}, ${params.userId}, ${googleEventId})
        ON CONFLICT (event_id, user_id) DO UPDATE SET google_event_id = ${googleEventId}
      `;
      D(`  ✓ google_event_ids upserted`);
    }
  } catch (err) {
    D(`  ✗ createGoogleEvent failed:`, err);
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
  D(`syncEventCreated — calendarId=${params.calendarId} eventId=${params.eventId} title="${params.title}"`);
  const members = await db`
    SELECT cm.user_id
    FROM calendar_members cm
    INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
    WHERE cm.calendar_id = ${params.calendarId}
  `;
  D(`  ${members.length} member(s) with gcal tokens`);
  for (const m of members as Record<string, unknown>[]) {
    D(`  syncing for userId=${m.user_id}`);
    await createGoogleEvent({ userId: m.user_id as string, ...params });
  }
  D(`  syncEventCreated done`);
}

export async function syncEventUpdated(params: {
  eventId: string;
  title: string;
  description?: string | null;
  startTime: Date;
  endTime: Date;
}): Promise<void> {
  D(`syncEventUpdated — eventId=${params.eventId} title="${params.title}"`);
  const rows = await db`
    SELECT gei.google_event_id, gct.access_token, gct.refresh_token, gei.user_id
    FROM google_event_ids gei
    INNER JOIN google_calendar_tokens gct ON gct.user_id = gei.user_id
    WHERE gei.event_id = ${params.eventId}
  `;
  D(`  ${rows.length} google_event_id row(s) found`);
  for (const row of rows as Record<string, unknown>[]) {
    D(`  updating googleEventId=${row.google_event_id} for userId=${row.user_id}`);
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
      D(`  ✓ updated`);
    } catch (err) {
      D(`  ✗ syncEventUpdated failed for userId=${row.user_id}:`, err);
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
  D(`fetchAndCacheGoogleEventsForCalendar — calendarId=${calendarId}`);
  D(`  window: ${startDate.toISOString()} → ${endDate.toISOString()}`);

  const calExists = await db`SELECT 1 FROM calendars WHERE id = ${calendarId} LIMIT 1`;
  if (calExists.length === 0) {
    D(`  ✗ calendar ${calendarId} no longer exists, skipping`);
    console.warn(`[gcal] calendar ${calendarId} no longer exists, skipping import`);
    return;
  }

  const memberRows = await db`
    SELECT cm.user_id, u.name, u.color, gct.access_token, gct.refresh_token, gct.expiry
    FROM calendar_members cm
    INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
    INNER JOIN users u ON u.id = cm.user_id
    WHERE cm.calendar_id = ${calendarId}
  `;
  D(`  ${memberRows.length} member(s) with gcal tokens`);
  if (memberRows.length === 0) {
    D(`  no gcal members — nothing to import`);
    return;
  }

  const ownedGoogleIds = await db`
    SELECT gei.google_event_id
    FROM google_event_ids gei
    INNER JOIN events e ON e.id = gei.event_id
    WHERE e.calendar_id = ${calendarId}
  `;
  D(`  ${ownedGoogleIds.length} owned google_event_id(s) to exclude`);
  const ownedIdSet = new Set(ownedGoogleIds.map((r: Record<string, unknown>) => r.google_event_id as string));

  const existingRows = await db`
    SELECT ical_uid, imported_by FROM imported_gcal_events WHERE calendar_id = ${calendarId}
  `;
  D(`  ${existingRows.length} existing imported_gcal_events row(s) in DB`);
  const importedByMap = new Map<string, ImportedByEntry[]>();
  for (const row of existingRows as Record<string, unknown>[]) {
    // Defensive: Bun SQL may return JSONB as a raw string — parse it if so.
    const importedBy: ImportedByEntry[] = typeof row.imported_by === 'string'
      ? JSON.parse(row.imported_by as string) as ImportedByEntry[]
      : (row.imported_by as ImportedByEntry[]) ?? [];
    importedByMap.set(row.ical_uid as string, importedBy);
  }

  for (const member of memberRows as Record<string, unknown>[]) {
    D(`  ── processing member userId=${member.user_id} name="${member.name}"`);
    try {
      const access = await decrypt(member.access_token as string);
      const refresh = await decrypt(member.refresh_token as string);
      const expiry = member.expiry ? new Date(member.expiry as string) : null;
      D(`    token expiry: ${expiry?.toISOString() ?? "(none)"}`);
      const auth = makeAuth(access, refresh, expiry);

      auth.on("tokens", async (newTokens) => {
        D(`    token refresh event for userId=${member.user_id}`);
        D(`      new access_token:  ${!!newTokens.access_token}`);
        D(`      new refresh_token: ${!!newTokens.refresh_token}`);
        D(`      new expiry_date:   ${newTokens.expiry_date ?? "(none)"}`);
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
          D(`      ✓ refreshed token persisted`);
          console.log(`[gcal import] refreshed token persisted for user ${member.user_id}`);
        } catch (e) {
          D(`      ✗ failed to persist refreshed token:`, e);
          console.error(`[gcal import] failed to persist refreshed token for user ${member.user_id}:`, e); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
        }
      });

      const cal = google.calendar({ version: "v3", auth });
      D(`    calling calendar.events.list (maxResults=250)…`);
      const res = await cal.events.list({
        calendarId: "primary",
        timeMin: startDate.toISOString(),
        timeMax: endDate.toISOString(),
        singleEvents: true,
        maxResults: 250,
      });

      const items = res.data.items ?? [];
      D(`    Google returned ${items.length} event(s) (nextPageToken=${res.data.nextPageToken ?? "none"})`);

      let skippedOwned = 0, skippedCancelled = 0, skippedNoDate = 0, skippedNoId = 0, skippedOrigin = 0, upserted = 0;

      const memberEntry: ImportedByEntry = {
        user_id: member.user_id as string,
        name: member.name as string,
        color: member.color as string,
      };

      for (const event of items) {
        if (event.extendedProperties?.private?.sharedcal_origin === "true") { skippedOrigin++; continue; }
        if (event.id && ownedIdSet.has(event.id)) { skippedOwned++; continue; }
        if (event.status === "cancelled") { skippedCancelled++; continue; }
        if (!event.start?.dateTime && !event.start?.date) { skippedNoDate++; continue; }
        if (!event.iCalUID && !event.id) { skippedNoId++; continue; }

        const icalUid = event.iCalUID || event.id!;
        let startTime: string;
        let endTime: string;
        if (event.start?.dateTime) {
          startTime = event.start.dateTime;
          endTime = event.end?.dateTime ?? event.start.dateTime;
        } else {
          startTime = `${event.start!.date}T00:00:00Z`;
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
             ${event.id ?? null}, ${JSON.stringify(merged)}::jsonb)
          ON CONFLICT (calendar_id, ical_uid) DO UPDATE SET
            title          = EXCLUDED.title,
            start_time     = EXCLUDED.start_time,
            end_time       = EXCLUDED.end_time,
            description    = EXCLUDED.description,
            google_event_id = EXCLUDED.google_event_id,
            imported_by    = EXCLUDED.imported_by,
            last_synced_at = now()
        `;
        upserted++;
      }

      D(`    summary: upserted=${upserted} skipped(origin=${skippedOrigin} owned=${skippedOwned} cancelled=${skippedCancelled} noDate=${skippedNoDate} noId=${skippedNoId})`);

    } catch (err: unknown) {
      const status = (err as { status?: number; code?: number })?.status
        ?? (err as { status?: number; code?: number })?.code;
      D(`    ✗ member ${member.user_id} failed — HTTP status=${status}`, err);
      if (status === 401 || status === 403) {
        D(`    revoking token for userId=${member.user_id} (${status})`);
        console.warn(`[gcal import] revoking token for user ${member.user_id}: HTTP ${status}`);
        await db`DELETE FROM google_calendar_tokens WHERE user_id = ${member.user_id}`;
      } else {
        console.error(`[gcal import] member ${member.user_id} failed:`, err); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
      }
    }
  }

  D(`  broadcasting gcal_synced for calendarId=${calendarId}`);
  broadcastToCalendar(calendarId, { type: "gcal_synced", calendar_id: calendarId });
  D(`fetchAndCacheGoogleEventsForCalendar DONE calendarId=${calendarId}`);
}

// ── Background scheduler ─────────────────────────────────────────────────────

let _schedulerRunning = false;

/**
 * Starts a background loop that re-imports Google Calendar events for every
 * calendar that has at least one member with Google Calendar connected.
 * Fires immediately on start, then every 5 minutes.
 * Skips a tick if the previous run is still in progress.
 */
export function startGoogleCalendarSyncScheduler(): void {
  const INTERVAL_MS = 5 * 60_000;

  async function runSync() {
    if (_schedulerRunning) {
      D("[gcal-scheduler] previous run still in progress — skipping tick");
      return;
    }
    _schedulerRunning = true;
    try {
      const now = new Date();
      const startDate = new Date(now.getFullYear() - 1, now.getMonth(), 1);
      const endDate = new Date(now.getFullYear() + 1, now.getMonth() + 1, 0);

      const rows = await db`
        SELECT DISTINCT cm.calendar_id
        FROM calendar_members cm
        INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
      `;
      D(`[gcal-scheduler] syncing ${rows.length} calendar(s)`);

      for (const row of rows as Record<string, unknown>[]) {
        await fetchAndCacheGoogleEventsForCalendar({
          calendarId: row.calendar_id as string,
          startDate,
          endDate,
        });
      }
    } catch (e) {
      console.error("[gcal-scheduler] sync failed:", e);
    } finally {
      _schedulerRunning = false;
    }
  }

  setInterval(() => { runSync().catch(console.error); }, INTERVAL_MS);
  D("[gcal-scheduler] started — interval=5min");
}

export async function syncEventDeleted(eventId: string): Promise<void> {
  D(`syncEventDeleted — eventId=${eventId}`);
  const rows = await db`
    SELECT gei.google_event_id, gct.access_token, gct.refresh_token, gei.user_id
    FROM google_event_ids gei
    INNER JOIN google_calendar_tokens gct ON gct.user_id = gei.user_id
    WHERE gei.event_id = ${eventId}
  `;
  D(`  ${rows.length} google_event_id row(s) to delete`);
  for (const row of rows as Record<string, unknown>[]) {
    D(`  deleting googleEventId=${row.google_event_id} for userId=${row.user_id}`);
    try {
      const access = await decrypt(row.access_token as string);
      const refresh = await decrypt(row.refresh_token as string);
      const cal = google.calendar({ version: "v3", auth: makeAuth(access, refresh) });
      await cal.events.delete({
        calendarId: "primary",
        eventId: row.google_event_id as string,
      });
      D(`  ✓ deleted`);
    } catch (err) {
      D(`  ✗ syncEventDeleted failed for userId=${row.user_id}:`, err);
      console.error(`[gcal] syncEventDeleted failed for user ${row.user_id}:`, err); // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring
    }
  }
  D(`syncEventDeleted DONE eventId=${eventId}`);
}
