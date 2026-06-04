import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";
import { isCloudinaryUrl, cleanupAssets } from "../services/cloudinary";

export async function addEventPhoto(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { eventId } = ctx.params;

  let body: { photo_url?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { photo_url } = body;
  if (!photo_url) return error("photo_url is required");
  if (!isCloudinaryUrl(photo_url)) return error("photo_url must be a Cloudinary URL");

  const events = await db`
    SELECT e.id, e.title, e.calendar_id, c.photo_mode
    FROM events e
    INNER JOIN calendars c ON c.id = e.calendar_id
    WHERE e.id = ${eventId}
  `;
  if (events.length === 0) return error("Event not found", 404);
  const event = events[0];

  if (!event.photo_mode) return error("This calendar does not have photo memories enabled", 403);

  const calendarId = event.calendar_id as string;

  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const photos = await db`
    INSERT INTO event_photos (event_id, calendar_id, uploaded_by, photo_url)
    VALUES (${eventId}, ${calendarId}, ${userId}, ${photo_url})
    RETURNING *
  `;
  const photo = photos[0];

  const users = await db`SELECT name FROM users WHERE id = ${userId}`;
  const uploaderName = (users[0]?.name as string) ?? "";

  broadcastToCalendar(calendarId, {
    type: "photo_added",
    photo: {
      id: photo.id,
      event_id: eventId,
      event_title: event.title,
      calendar_id: calendarId,
      uploaded_by: userId,
      uploaded_by_name: uploaderName,
      photo_url: photo_url,
      created_at: (photo.created_at as Date).toISOString(),
    },
  });

  return json({ ...photo, uploaded_by_name: uploaderName, event_title: event.title }, 201);
}

export async function listCalendarPhotos(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { calendarId } = ctx.params;

  const membership = await db`
    SELECT 1 FROM calendar_members WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const photos = await db`
    SELECT
      ep.id,
      ep.event_id,
      ep.calendar_id,
      ep.uploaded_by,
      u.name AS uploaded_by_name,
      ep.photo_url,
      ep.created_at,
      e.title AS event_title,
      e.start_time AS event_start_time
    FROM event_photos ep
    LEFT JOIN users u ON u.id = ep.uploaded_by
    LEFT JOIN events e ON e.id = ep.event_id
    WHERE ep.calendar_id = ${calendarId}
    ORDER BY ep.created_at DESC
  `;

  return json(photos);
}

export async function deleteEventPhoto(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { eventId, photoId } = ctx.params;

  const photos = await db`
    SELECT ep.*, cm.role
    FROM event_photos ep
    INNER JOIN calendar_members cm ON cm.calendar_id = ep.calendar_id AND cm.user_id = ${userId}
    WHERE ep.id = ${photoId} AND ep.event_id = ${eventId}
  `;
  if (photos.length === 0) return error("Photo not found", 404);
  const photo = photos[0];

  if (photo.uploaded_by !== userId && photo.role !== "owner") {
    return error("Not authorized to delete this photo", 403);
  }

  await db`DELETE FROM event_photos WHERE id = ${photoId}`;
  cleanupAssets([photo.photo_url as string]);

  broadcastToCalendar(photo.calendar_id as string, {
    type: "photo_deleted",
    photo_id: photoId,
    event_id: eventId,
    calendar_id: photo.calendar_id,
  });

  return json({ message: "Photo deleted" });
}
