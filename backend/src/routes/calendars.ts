import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";
import { cleanupAssets } from "../services/cloudinary";
import { fetchAndCacheGoogleEventsForCalendar } from "../services/google_calendar";

function generateInviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 8 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
}

export async function listCalendars(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;

  const calendars = await db`
    SELECT c.id, c.name, c.owner_id, c.invite_code, c.created_at, c.photo_mode,
           c.hue_index, c.icon,
           cm.role,
           (SELECT COUNT(*)::integer FROM calendar_members WHERE calendar_id = c.id) AS member_count
    FROM calendars c
    INNER JOIN calendar_members cm ON cm.calendar_id = c.id AND cm.user_id = ${userId}
    ORDER BY c.created_at DESC
  `;

  return json(calendars);
}

export async function createCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  let body: { name?: string; photo_mode?: boolean; hue_index?: number; icon?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  if (!body.name?.trim()) return error("name is required");
  const photoMode = body.photo_mode === true;
  const hueIndex = typeof body.hue_index === 'number' ? Math.max(0, Math.min(7, Math.round(body.hue_index))) : 0;
  const icon = typeof body.icon === 'string' ? body.icon : null;

  let inviteCode: string;
  // Ensure unique invite code
  while (true) {
    inviteCode = generateInviteCode();
    const existing = await db`SELECT id FROM calendars WHERE invite_code = ${inviteCode}`;
    if (existing.length === 0) break;
  }

  const calendars = await db`
    INSERT INTO calendars (name, owner_id, invite_code, photo_mode, hue_index, icon)
    VALUES (${body.name.trim()}, ${userId}, ${inviteCode}, ${photoMode}, ${hueIndex}, ${icon})
    RETURNING *
  `;
  const calendar = calendars[0];

  // Add creator as owner member
  await db`
    INSERT INTO calendar_members (user_id, calendar_id, role)
    VALUES (${userId}, ${calendar.id}, 'owner')
  `;

  return json({ ...calendar, role: "owner", member_count: 1 }, 201);
}

export async function joinCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  let body: { invite_code?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  if (!body.invite_code) return error("invite_code is required");

  const calendars = await db`SELECT * FROM calendars WHERE invite_code = ${body.invite_code.toUpperCase()}`;
  if (calendars.length === 0) return error("Invalid invite code", 404);

  const calendar = calendars[0];

  // Check already a member
  const existing = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${calendar.id}
  `;
  if (existing.length > 0) return error("Already a member of this calendar", 409);

  await db`
    INSERT INTO calendar_members (user_id, calendar_id, role)
    VALUES (${userId}, ${calendar.id}, 'member')
  `;

  const count = await db`SELECT COUNT(*)::integer AS member_count FROM calendar_members WHERE calendar_id = ${calendar.id}`;
  const memberCount = count[0].member_count as number;

  // If the joining user has Google Calendar connected, immediately import their
  // events into this calendar. This bypasses the 5-min staleness check that
  // getCalendarEvents uses, so their events appear without any delay.
  const gcalTokens = await db`SELECT 1 FROM google_calendar_tokens WHERE user_id = ${userId} LIMIT 1`;
  if (gcalTokens.length > 0) {
    const now = new Date();
    const startDate = new Date(now.getFullYear() - 1, now.getMonth(), 1);
    const endDate = new Date(now.getFullYear() + 1, now.getMonth() + 1, 0);
    fetchAndCacheGoogleEventsForCalendar({ calendarId: calendar.id, startDate, endDate })
      .catch((e: unknown) => console.error("[gcal] join-triggered import failed:", e));
  }

  // Notify existing members that someone joined
  broadcastToCalendar(calendar.id, {
    type: "member_joined",
    calendar_id: calendar.id,
    member_count: memberCount,
  });

  return json({ ...calendar, role: "member", member_count: memberCount });
}

export async function getCalendarEvents(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  // Verify membership
  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  // Recurring instances are stored as DB rows (parent_event_id set), so a simple
  // query returns both the root event and all its generated instances.
  const events = await db`
    SELECT e.*, u.name AS creator_name, u.color AS creator_color
    FROM events e
    LEFT JOIN users u ON u.id = e.created_by
    WHERE e.calendar_id = ${id}
    ORDER BY e.start_time ASC
  `;

  // Date window for Google import (defaults to ±1 year when frontend sends no params)
  const now = new Date();
  const startDate = ctx.query.start
    ? new Date(ctx.query.start)
    : new Date(now.getFullYear() - 1, now.getMonth(), 1);
  const endDate = ctx.query.end
    ? new Date(ctx.query.end)
    : new Date(now.getFullYear() + 1, now.getMonth() + 1, 0);

  // Only run the Google Calendar import pipeline when at least one calendar member
  // has connected their Google Calendar. Avoids an infinite needsRefresh=true loop
  // (imported_gcal_events stays empty → MIN(last_synced_at) is always NULL →
  // background refresh fires on every request → memberRows=0 → no gcal_synced).
  console.log("[gcal-debug] getCalendarEvents — calendarId=%s window=%s→%s",
    id, startDate.toISOString().substring(0, 10), endDate.toISOString().substring(0, 10));
  const gcalMembers = await db`
    SELECT 1 FROM calendar_members cm
    INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
    WHERE cm.calendar_id = ${id}
    LIMIT 1
  `;
  console.log("[gcal-debug]   gcalMembers with tokens: %d", gcalMembers.length);

  if (gcalMembers.length > 0) {
    const staleness = await db`
      SELECT MIN(last_synced_at) AS oldest
      FROM imported_gcal_events
      WHERE calendar_id = ${id}
        AND end_time > ${startDate}
        AND start_time < ${endDate}
    `;
    const oldest = staleness[0]?.oldest as Date | null;
    const ageMs = oldest ? Date.now() - new Date(oldest).getTime() : null;
    const needsRefresh = !oldest || (ageMs !== null && ageMs > 5 * 60 * 1000);
    console.log("[gcal-debug]   oldest_synced=%s age_min=%s needsRefresh=%s",
      oldest ? new Date(oldest).toISOString() : "NULL",
      ageMs !== null ? (ageMs / 60_000).toFixed(1) : "N/A",
      needsRefresh);
    if (needsRefresh) {
      console.log("[gcal-debug]   → firing background fetchAndCacheGoogleEventsForCalendar");
      fetchAndCacheGoogleEventsForCalendar({ calendarId: id, startDate, endDate })
        .catch((e: unknown) => {
          console.error("[gcal-debug]   background refresh FAILED:", e);
          console.error("[gcal import] background refresh failed:", e);
        });
    } else {
      console.log("[gcal-debug]   → cache fresh, skipping import");
    }
  }

  // Read cached imported Google Calendar events for this calendar and date window
  const importedRows = await db`
    SELECT *
    FROM imported_gcal_events
    WHERE calendar_id = ${id}
      AND end_time > ${startDate}
      AND start_time < ${endDate}
    ORDER BY start_time ASC
  `;

  console.log("[gcal-debug]   imported_gcal_events from cache: %d row(s)", importedRows.length);
  const importedEvents = (importedRows as Record<string, unknown>[]).map((row) => ({
    id: row.id,
    calendar_id: row.calendar_id,
    created_by: null,
    title: row.title,
    description: row.description ?? null,
    start_time: row.start_time,
    end_time: row.end_time,
    color: "#6C63FF",
    created_at: row.last_synced_at,
    updated_at: row.last_synced_at,
    source: "google_import",
    // Defensive: Bun SQL may return JSONB as a raw string — parse it if so.
    imported_by: typeof row.imported_by === 'string'
      ? JSON.parse(row.imported_by as string)
      : (row.imported_by ?? []),
  }));

  // Read device calendar events uploaded by members
  const deviceRows = await db`
    SELECT ide.*, u.name AS contributed_by_name, u.color AS contributed_by_color
    FROM imported_device_events ide
    INNER JOIN users u ON u.id = ide.user_id
    WHERE ide.calendar_id = ${id}
      AND ide.end_time > ${startDate}
      AND ide.start_time < ${endDate}
    ORDER BY ide.start_time ASC
  `;

  console.log("[device-sync] getCalendarEvents calendarId=%s window=%s→%s → device_import rows=%d",
    id,
    startDate.toISOString().substring(0, 10),
    endDate.toISOString().substring(0, 10),
    deviceRows.length,
  );
  for (const row of deviceRows as Record<string, unknown>[]) {
    console.log("[device-sync]   row: device_event_id=%s title=%s user=%s start=%s",
      row.device_event_id,
      row.title,
      row.user_id,
      row.start_time instanceof Date
        ? (row.start_time as Date).toISOString().substring(0, 10)
        : String(row.start_time).substring(0, 10),
    );
  }

  const deviceImportedEvents = (deviceRows as Record<string, unknown>[]).map((row) => ({
    id: `device_${row.device_event_id as string}`,
    calendar_id: row.calendar_id,
    created_by: row.user_id,
    title: row.title,
    description: row.description ?? null,
    start_time: row.start_time,
    end_time: row.end_time,
    color: row.contributed_by_color ?? "#6C63FF",
    created_at: row.last_synced_at,
    updated_at: row.last_synced_at,
    source: "device_import",
    imported_by: [{
      user_id: row.user_id,
      name: row.contributed_by_name,
      color: row.contributed_by_color ?? "#6C63FF",
    }],
  }));

  console.log("[device-sync] getCalendarEvents: returning %d total events (%d sharedcal, %d gcal, %d device)",
    events.length + importedEvents.length + deviceImportedEvents.length,
    events.length, importedEvents.length, deviceImportedEvents.length,
  );
  return json([...events, ...importedEvents, ...deviceImportedEvents]);
}

export async function listMembers(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  // Verify membership
  const membership = await db`
    SELECT role FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const members = await db`
    SELECT u.id, u.email, u.name, u.color, u.avatar_url, cm.role, cm.joined_at
    FROM users u
    INNER JOIN calendar_members cm ON cm.user_id = u.id
    WHERE cm.calendar_id = ${id}
    ORDER BY cm.joined_at ASC NULLS LAST
  `;

  return json(members);
}

async function cleanupImportedDeviceEvents(calendarId: string, departedUserId: string): Promise<void> {
  await db`
    DELETE FROM imported_device_events
    WHERE calendar_id = ${calendarId} AND user_id = ${departedUserId}
  `;
}

async function cleanupImportedGcalEvents(calendarId: string, departedUserId: string): Promise<void> {
  await db`
    UPDATE imported_gcal_events
    SET imported_by = (
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      FROM jsonb_array_elements(imported_by) AS elem
      WHERE elem->>'user_id' != ${departedUserId}
    )
    WHERE calendar_id = ${calendarId}
  `;
  await db`
    DELETE FROM imported_gcal_events
    WHERE calendar_id = ${calendarId}
      AND jsonb_array_length(imported_by) = 0
  `;
}

export async function removeMember(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id, userId: targetUserId } = ctx.params;

  // Verify current user is owner
  const membership = await db`
    SELECT role FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0 || membership[0].role !== 'owner') {
    return error("Only the calendar owner can remove members", 403);
  }

  if (userId === targetUserId) {
    return error("You cannot remove yourself from your own calendar", 400);
  }

  await db`
    DELETE FROM calendar_members
    WHERE calendar_id = ${id} AND user_id = ${targetUserId}
  `;

  await cleanupImportedGcalEvents(id, targetUserId);
  await cleanupImportedDeviceEvents(id, targetUserId);

  return json({ message: "Member removed" });
}

export async function deleteCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const membership = await db`
    SELECT role FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0 || membership[0].role !== 'owner') {
    return error("Only the calendar owner can delete this calendar", 403);
  }

  // Clean up any Cloudinary photo icons on events in this calendar (fire-and-forget)
  const eventIcons = await db`SELECT icon FROM events WHERE calendar_id = ${id}`;
  cleanupAssets(eventIcons.map((e: Record<string, unknown>) => e.icon as string | null));

  // Clean up event memory photos for this calendar (fire-and-forget)
  const photoUrls = await db`SELECT photo_url FROM event_photos WHERE calendar_id = ${id}`;
  cleanupAssets(photoUrls.map((p: Record<string, unknown>) => p.photo_url as string));

  // Notify all connected members before the row is deleted so their WS
  // subscriptions are still active when the broadcast fires.
  broadcastToCalendar(id, { type: "calendar_deleted", calendar_id: id });

  await db`DELETE FROM calendars WHERE id = ${id}`;
  return json({ message: "Calendar deleted" });
}

export async function leaveCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const membership = await db`
    SELECT role FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 404);
  if (membership[0].role === 'owner') {
    return error("Calendar owner cannot leave. Delete the calendar instead.", 400);
  }

  await db`DELETE FROM calendar_members WHERE calendar_id = ${id} AND user_id = ${userId}`;

  await cleanupImportedGcalEvents(id, userId);
  await cleanupImportedDeviceEvents(id, userId);

  return json({ message: "Left calendar" });
}

export async function patchCalendar(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const membership = await db`SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}`;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  let body: { hue_index?: number; icon?: string | null };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  if (body.hue_index !== undefined) {
    const idx = Math.max(0, Math.min(7, Math.round(body.hue_index)));
    await db`UPDATE calendars SET hue_index = ${idx} WHERE id = ${id}`;
  }
  if ('icon' in body) {
    const iconVal = typeof body.icon === 'string' ? body.icon : null;
    await db`UPDATE calendars SET icon = ${iconVal} WHERE id = ${id}`;
  }

  const rows = await db`SELECT * FROM calendars WHERE id = ${id}`;
  return json(rows[0]);
}

interface DeviceEventInput {
  device_event_id: string;
  title: string;
  start_time: string;
  end_time: string;
  description?: string | null;
}

/// POST /calendars/:id/device-events
/// Replaces the calling user's device calendar events for this calendar.
/// All members of the calendar can then see these events in getCalendarEvents.
export async function syncDeviceEvents(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  console.log("[device-sync] syncDeviceEvents: userId=%s calendarId=%s", userId, id);

  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0) {
    console.log("[device-sync] syncDeviceEvents: REJECTED — user=%s is not a member of calendar=%s", userId, id);
    return error("Not a member of this calendar", 403);
  }

  let body: { events?: DeviceEventInput[] };
  try {
    body = await ctx.req.json();
  } catch {
    console.log("[device-sync] syncDeviceEvents: REJECTED — invalid JSON body");
    return error("Invalid JSON body");
  }

  const events = Array.isArray(body.events) ? body.events : [];
  console.log("[device-sync] syncDeviceEvents: received %d events from user=%s", events.length, userId);
  for (const ev of events) {
    console.log("[device-sync]   event: id=%s title=%s start=%s valid=%s",
      ev.device_event_id,
      ev.title,
      ev.start_time?.toString().substring(0, 10) ?? "null",
      !!(ev.device_event_id && ev.title && ev.start_time && ev.end_time),
    );
  }

  // Replace all device events for this user in this calendar atomically.
  // We delete first to remove events that no longer exist on the device, then
  // upsert each incoming event. The ON CONFLICT clause handles iOS recurring
  // events that share the same eventId across annual occurrences (e.g. public
  // holidays) — without it the second INSERT would crash with a UNIQUE
  // constraint violation → HTTP 500.
  await db`DELETE FROM imported_device_events WHERE calendar_id = ${id} AND user_id = ${userId}`;
  console.log("[device-sync] syncDeviceEvents: deleted previous rows for user=%s", userId);

  let inserted = 0;
  let skipped = 0;
  for (const event of events) {
    if (!event.device_event_id || !event.title || !event.start_time || !event.end_time) {
      console.log("[device-sync]   SKIPPING invalid event: id=%s title=%s", event.device_event_id, event.title);
      skipped++;
      continue;
    }
    await db`
      INSERT INTO imported_device_events
        (calendar_id, user_id, device_event_id, title, start_time, end_time, description)
      VALUES
        (${id}, ${userId}, ${event.device_event_id}, ${event.title},
         ${event.start_time}, ${event.end_time}, ${event.description ?? null})
      ON CONFLICT (calendar_id, user_id, device_event_id)
      DO UPDATE SET
        title       = EXCLUDED.title,
        start_time  = EXCLUDED.start_time,
        end_time    = EXCLUDED.end_time,
        description = EXCLUDED.description
    `;
    inserted++;
  }

  console.log("[device-sync] syncDeviceEvents: inserted=%d skipped=%d — broadcasting device_synced", inserted, skipped);

  // Notify all calendar members so their UI re-fetches and shows the new events
  broadcastToCalendar(id, { type: "device_synced", calendar_id: id });

  return json({ synced: inserted });
}
