import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";

const VALID_STATUSES = ["attending", "not_attending", "unsure"];

function mapUser(r: Record<string, unknown>) {
  return {
    user_id: r.user_id,
    user_name: r.user_name,
    avatar_url: r.avatar_url ?? null,
    color: r.color ?? null,
  };
}

async function assembleRsvpDetail(eventId: string, callerId: string) {
  const rows = await db`
    SELECT r.user_id, r.status, u.name AS user_name, u.avatar_url, u.color
    FROM event_rsvps r
    JOIN users u ON u.id = r.user_id
    WHERE r.event_id = ${eventId}
    ORDER BY r.responded_at ASC
  `;

  const attending = rows
    .filter((r: Record<string, unknown>) => r.status === "attending")
    .map(mapUser);
  const notAttending = rows
    .filter((r: Record<string, unknown>) => r.status === "not_attending")
    .map(mapUser);
  const unsure = rows
    .filter((r: Record<string, unknown>) => r.status === "unsure")
    .map(mapUser);
  const myRow = rows.find(
    (r: Record<string, unknown>) => r.user_id === callerId
  );

  return {
    attending,
    not_attending: notAttending,
    unsure,
    my_status: myRow ? (myRow.status as string) : null,
  };
}

// POST /events/:id/rsvp — upsert attendance status
export async function setRsvp(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  let body: { status?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { status } = body;
  if (!status || !VALID_STATUSES.includes(status)) {
    return error("status must be attending, not_attending, or unsure");
  }

  const events = await db`SELECT calendar_id FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const calendarId = events[0].calendar_id as string;

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  await db`
    INSERT INTO event_rsvps (event_id, user_id, status)
    VALUES (${id}, ${userId}, ${status})
    ON CONFLICT (event_id, user_id) DO UPDATE SET status = ${status}, responded_at = now()
  `;

  broadcastToCalendar(calendarId, {
    type: "rsvp_update",
    event_id: id,
    calendar_id: calendarId,
  });

  return json(await assembleRsvpDetail(id, userId));
}

// DELETE /events/:id/rsvp — remove own RSVP
export async function deleteRsvp(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const events = await db`SELECT calendar_id FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const calendarId = events[0].calendar_id as string;

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  await db`DELETE FROM event_rsvps WHERE event_id = ${id} AND user_id = ${userId}`;

  broadcastToCalendar(calendarId, {
    type: "rsvp_update",
    event_id: id,
    calendar_id: calendarId,
  });

  return json(await assembleRsvpDetail(id, userId));
}

// GET /events/:id/rsvps — full detail (voter names) for the event detail screen
export async function getRsvpDetail(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const events = await db`SELECT calendar_id FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const calendarId = events[0].calendar_id as string;

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  return json(await assembleRsvpDetail(id, userId));
}

// GET /calendars/:id/rsvps — summary map for all events (home screen + polls tab)
export async function getCalendarRsvps(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const rows = await db`
    SELECT
      r.event_id,
      SUM(CASE WHEN r.status = 'attending'     THEN 1 ELSE 0 END)::integer AS attending_count,
      SUM(CASE WHEN r.status = 'not_attending' THEN 1 ELSE 0 END)::integer AS not_attending_count,
      SUM(CASE WHEN r.status = 'unsure'        THEN 1 ELSE 0 END)::integer AS unsure_count,
      MAX(CASE WHEN r.user_id = ${userId} THEN r.status END) AS my_status
    FROM event_rsvps r
    INNER JOIN events e ON e.id = r.event_id
    WHERE e.calendar_id = ${id}
    GROUP BY r.event_id
  `;

  const result: Record<
    string,
    {
      attending_count: number;
      not_attending_count: number;
      unsure_count: number;
      my_status: string | null;
    }
  > = {};

  for (const row of rows) {
    result[row.event_id as string] = {
      attending_count: row.attending_count as number,
      not_attending_count: row.not_attending_count as number,
      unsure_count: row.unsure_count as number,
      my_status: (row.my_status as string | null) ?? null,
    };
  }

  return json(result);
}
