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
  const gcalMembers = await db`
    SELECT 1 FROM calendar_members cm
    INNER JOIN google_calendar_tokens gct ON gct.user_id = cm.user_id
    WHERE cm.calendar_id = ${id}
    LIMIT 1
  `;

  if (gcalMembers.length > 0) {
    // Fire-and-forget background refresh when cache is stale (>5 min) or empty.
    // Scope the staleness check to the current window so out-of-range archived
    // rows don't permanently keep needsRefresh true.
    const staleness = await db`
      SELECT MIN(last_synced_at) AS oldest
      FROM imported_gcal_events
      WHERE calendar_id = ${id}
        AND start_time >= ${startDate}
        AND start_time < ${endDate}
    `;
    const oldest = staleness[0]?.oldest as Date | null;
    const needsRefresh = !oldest || Date.now() - new Date(oldest).getTime() > 5 * 60 * 1000;
    if (needsRefresh) {
      fetchAndCacheGoogleEventsForCalendar({ calendarId: id, startDate, endDate })
        .catch((e: unknown) => console.error("[gcal import] background refresh failed:", e));
    }
  }

  // Read cached imported Google Calendar events for this calendar and date window
  const importedRows = await db`
    SELECT *
    FROM imported_gcal_events
    WHERE calendar_id = ${id}
      AND start_time >= ${startDate}
      AND start_time < ${endDate}
    ORDER BY start_time ASC
  `;

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
    imported_by: row.imported_by,
  }));

  return json([...events, ...importedEvents]);
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
