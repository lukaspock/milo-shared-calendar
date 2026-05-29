import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";
import { sendEventNotification } from "../services/email";
import { syncEventCreated, syncEventUpdated, syncEventDeleted } from "../services/google_calendar";

export async function createEvent(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  let body: {
    calendar_id?: string;
    title?: string;
    description?: string;
    start_time?: string;
    end_time?: string;
    color?: string;
  };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { calendar_id, title, start_time, end_time, description, color } = body;
  if (!calendar_id || !title || !start_time || !end_time) {
    return error("calendar_id, title, start_time and end_time are required");
  }

  // Verify membership
  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  // Get user color as default event color
  let eventColor = color;
  if (!eventColor) {
    const users = await db`SELECT color FROM users WHERE id = ${userId}`;
    eventColor = users[0]?.color ?? "#6C63FF";
  }

  const events = await db`
    INSERT INTO events (calendar_id, created_by, title, description, start_time, end_time, color)
    VALUES (${calendar_id}, ${userId}, ${title}, ${description ?? null}, ${start_time}, ${end_time}, ${eventColor})
    RETURNING *
  `;

  const event = events[0];

  // Fire-and-forget: email notifications + Google Calendar sync
  (async () => {
    const creator = await db`SELECT name FROM users WHERE id = ${userId}`;
    const members = await db`
      SELECT u.email FROM users u
      INNER JOIN calendar_members cm ON cm.user_id = u.id
      WHERE cm.calendar_id = ${calendar_id} AND u.id != ${userId}
        AND u.email_verified = true AND u.notification_type = 'email'
    `;
    const cal = await db`SELECT name FROM calendars WHERE id = ${calendar_id}`;
    if (members.length > 0 && cal.length > 0) {
      await sendEventNotification({
        memberEmails: members.map((m: Record<string, unknown>) => m.email as string),
        eventTitle: event.title as string,
        calendarName: cal[0].name as string,
        startTime: new Date(event.start_time as string),
        creatorName: creator[0]?.name as string ?? "Someone",
      });
    }
    await syncEventCreated({
      calendarId: calendar_id,
      eventId: event.id as string,
      title: event.title as string,
      description: event.description as string | null,
      startTime: new Date(event.start_time as string),
      endTime: new Date(event.end_time as string),
    });
  })().catch(console.error);

  return json(event, 201);
}

export async function updateEvent(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;
  let body: {
    title?: string;
    description?: string;
    start_time?: string;
    end_time?: string;
    color?: string;
  };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  // Fetch event to verify existence and membership
  const events = await db`SELECT * FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const event = events[0];

  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${event.calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const updated = await db`
    UPDATE events SET
      title = ${body.title ?? event.title},
      description = ${body.description ?? event.description},
      start_time = ${body.start_time ?? event.start_time},
      end_time = ${body.end_time ?? event.end_time},
      color = ${body.color ?? event.color}
    WHERE id = ${id}
    RETURNING *
  `;

  const u = updated[0];
  syncEventUpdated({
    eventId: id,
    title: u.title as string,
    description: u.description as string | null,
    startTime: new Date(u.start_time as string),
    endTime: new Date(u.end_time as string),
  }).catch(console.error);

  return json(u);
}

export async function deleteEvent(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const events = await db`SELECT * FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const event = events[0];

  // Must be member of the calendar
  const membership = await db`
    SELECT role FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${event.calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  // Only creator or calendar owner can delete
  const isCreator = event.created_by === userId;
  const isOwner = membership[0].role === "owner";
  if (!isCreator && !isOwner) return error("Only the event creator or calendar owner can delete events", 403);

  // Sync Google Calendar deletions before removing the DB row (cascade deletes google_event_ids)
  syncEventDeleted(id).catch(console.error);

  await db`DELETE FROM events WHERE id = ${id}`;

  return json({ message: "Event deleted" });
}

export async function notifyMembers(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const events = await db`SELECT * FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const event = events[0];

  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${event.calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const sender = await db`SELECT name FROM users WHERE id = ${userId}`;
  const senderName = sender[0]?.name ?? "Someone";

  broadcastToCalendar(event.calendar_id, {
    type: "member_notification",
    event_id: event.id,
    event_title: event.title,
    sender_name: senderName,
    message: `${senderName} is reminding you about "${event.title}"`,
  });

  return json({ message: "Members notified" });
}
