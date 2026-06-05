import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";
import { sendEventNotification } from "../services/email";
import { syncEventCreated, syncEventUpdated, syncEventDeleted } from "../services/google_calendar";
import { cleanupAssets } from "../services/cloudinary";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function advanceDate(date: Date, rule: string): Date {
  const d = new Date(date);
  if (rule === "daily")        d.setDate(d.getDate() + 1);
  else if (rule === "weekly")  d.setDate(d.getDate() + 7);
  else if (rule === "monthly") d.setMonth(d.getMonth() + 1);
  return d;
}

/** Insert recurring instances into the DB (up to 500, within 3 months if no end date) */
async function insertRecurringInstances(
  parentId: string,
  calendarId: string,
  createdBy: string,
  title: string,
  description: string | null,
  baseStart: Date,
  baseEnd: Date,
  color: string,
  rule: string,
  recurrenceEnd: string | null,
): Promise<void> {
  const duration = baseEnd.getTime() - baseStart.getTime();
  const cutoff = recurrenceEnd
    ? new Date(recurrenceEnd)
    : new Date(Date.now() + 90 * 24 * 60 * 60 * 1000); // 3 months

  let cursor = new Date(baseStart);
  let count = 0;

  while (count < 500) {
    cursor = advanceDate(cursor, rule);
    if (cursor > cutoff) break;
    count++;

    const instStart = new Date(cursor);
    const instEnd   = new Date(instStart.getTime() + duration);

    await db`
      INSERT INTO events
        (calendar_id, created_by, title, description, start_time, end_time, color,
         recurrence_rule, recurrence_end, parent_event_id)
      VALUES
        (${calendarId}, ${createdBy}, ${title}, ${description ?? null},
         ${instStart.toISOString()}, ${instEnd.toISOString()}, ${color},
         ${rule}, ${recurrenceEnd ?? null}, ${parentId})
    `;
  }
}

export async function createEvent(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  let body: {
    calendar_id?: string;
    title?: string;
    description?: string;
    start_time?: string;
    end_time?: string;
    color?: string;
    icon?: string;
    recurrence_rule?: string;
    recurrence_end?: string;
  };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { calendar_id, title, start_time, end_time, description, color, icon, recurrence_rule, recurrence_end } = body;
  if (!calendar_id || !title || !start_time || !end_time) {
    return error("calendar_id, title, start_time and end_time are required");
  }
  const validRules = [undefined, null, "daily", "weekly", "monthly"];
  if (recurrence_rule !== undefined && !validRules.includes(recurrence_rule)) {
    return error("recurrence_rule must be 'daily', 'weekly', or 'monthly'");
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
    INSERT INTO events (calendar_id, created_by, title, description, start_time, end_time, color, icon, recurrence_rule, recurrence_end)
    VALUES (${calendar_id}, ${userId}, ${title}, ${description ?? null}, ${start_time}, ${end_time}, ${eventColor},
            ${icon ?? null}, ${recurrence_rule ?? null}, ${recurrence_end ?? null})
    RETURNING *
  `;

  const event = events[0];

  // Generate recurring instances in the DB (fire-and-forget to not block response)
  if (recurrence_rule) {
    insertRecurringInstances(
      event.id as string,
      calendar_id,
      userId,
      title,
      description ?? null,
      new Date(start_time),
      new Date(end_time),
      eventColor!,
      recurrence_rule,
      recurrence_end ?? null,
    ).catch(console.error);
  }

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
    icon?: string | null;
    recurrence_rule?: string | null;
    recurrence_end?: string | null;
    edit_all?: boolean;
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
    SELECT role FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${event.calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const isCreator = event.created_by === userId;
  const isOwner = membership[0].role === "owner";
  if (!isCreator && !isOwner) return error("Only the event creator or calendar owner can edit this event", 403);


  if (body.edit_all) {
    // Update this event and all future instances in the series
    const rootId = (event.parent_event_id ?? event.id) as string;
    const newTitle       = body.title ?? (event.title as string);
    const newDescription = 'description' in body ? (body.description ?? null) : (event.description as string | null);
    const newColor       = body.color ?? (event.color as string);
    const newRule        = 'recurrence_rule' in body ? (body.recurrence_rule ?? null) : (event.recurrence_rule as string | null);
    const newEnd         = 'recurrence_end'  in body ? (body.recurrence_end  ?? null) : (event.recurrence_end  as string | null);
    const fromTime       = event.start_time as string;

    const oldIcon = event.icon as string | null;
    const newIcon = 'icon' in body ? (body.icon ?? null) : oldIcon;
    await db`
      UPDATE events SET
        title           = ${newTitle},
        description     = ${newDescription},
        color           = ${newColor},
        icon            = ${newIcon},
        recurrence_rule = ${newRule},
        recurrence_end  = ${newEnd}
      WHERE (id = ${rootId} OR parent_event_id = ${rootId})
        AND start_time >= ${fromTime}
    `;
    // Delete old Cloudinary icon if it was replaced
    if ('icon' in body && oldIcon !== newIcon) cleanupAssets([oldIcon]);
    const updatedRows = await db`SELECT * FROM events WHERE id = ${id}`;
    const ue = updatedRows[0];
    syncEventUpdated({
      eventId: id,
      title: ue.title as string,
      description: ue.description as string | null,
      startTime: new Date(ue.start_time as string),
      endTime: new Date(ue.end_time as string),
    }).catch(console.error);
    return json(ue);
  }

  const oldIcon = event.icon as string | null;
  const updated = await db`
    UPDATE events SET
      title = ${body.title ?? event.title},
      description = ${body.description ?? event.description},
      start_time = ${body.start_time ?? event.start_time},
      end_time = ${body.end_time ?? event.end_time},
      color = ${body.color ?? event.color},
      icon = ${'icon' in body ? (body.icon ?? null) : event.icon},
      recurrence_rule = ${'recurrence_rule' in body ? (body.recurrence_rule ?? null) : event.recurrence_rule},
      recurrence_end  = ${'recurrence_end'  in body ? (body.recurrence_end  ?? null) : event.recurrence_end}
    WHERE id = ${id}
    RETURNING *
  `;

  // Delete old Cloudinary icon if it was replaced
  if ('icon' in body && oldIcon !== (body.icon ?? null)) cleanupAssets([oldIcon]);

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

  // Check if caller wants to delete all events in the series
  let deleteAll = false;
  try {
    const body = await ctx.req.json() as Record<string, unknown>;
    deleteAll = body.delete_all === true;
  } catch {
    // No body or non-JSON — default to single delete
  }

  if (deleteAll) {
    // Delete root event — ON DELETE CASCADE removes all child instances automatically
    const rootId = (event.parent_event_id ?? event.id) as string;
    const series = await db`SELECT icon FROM events WHERE id = ${rootId} OR parent_event_id = ${rootId}`;
    cleanupAssets(series.map((e: Record<string, unknown>) => e.icon as string | null));
    syncEventDeleted(rootId).catch(console.error);
    await db`DELETE FROM events WHERE id = ${rootId}`;
    return json({ message: "All events in series deleted" });
  }

  // Single-instance delete
  cleanupAssets([event.icon as string | null]);
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
