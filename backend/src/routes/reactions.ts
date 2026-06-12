import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";

export async function getReactions(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  const events = await db`SELECT calendar_id FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${events[0].calendar_id}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  const reactions = await db`
    SELECT er.emoji, er.user_id, u.name AS user_name, er.created_at
    FROM event_reactions er
    JOIN users u ON u.id = er.user_id
    WHERE er.event_id = ${id}
    ORDER BY er.created_at
  `;

  return json(reactions);
}

export async function addReaction(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id } = ctx.params;

  let body: { emoji?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { emoji } = body;
  if (!emoji) return error("emoji is required");
  if (
    typeof emoji !== "string" ||
    emoji.length < 1 ||
    emoji.length > 10 ||
    Array.from(emoji).some((ch) => ch.charCodeAt(0) < 32)
  ) {
    return error("Invalid emoji", 400);
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
    INSERT INTO event_reactions (event_id, user_id, emoji)
    VALUES (${id}, ${userId}, ${emoji})
    ON CONFLICT (event_id, user_id, emoji) DO NOTHING
  `;

  broadcastToCalendar(calendarId, {
    type: "reaction_update",
    event_id: id,
    calendar_id: calendarId,
  });

  const reactions = await db`
    SELECT er.emoji, er.user_id, u.name AS user_name, er.created_at
    FROM event_reactions er
    JOIN users u ON u.id = er.user_id
    WHERE er.event_id = ${id}
    ORDER BY er.created_at
  `;

  return json(reactions, 201);
}

export async function removeReaction(ctx: RequestContext): Promise<Response> {
  const userId = ctx.user!.sub;
  const { id, emoji } = ctx.params;

  const events = await db`SELECT calendar_id FROM events WHERE id = ${id}`;
  if (events.length === 0) return error("Event not found", 404);
  const calendarId = events[0].calendar_id as string;

  const membership = await db`
    SELECT 1 FROM calendar_members
    WHERE user_id = ${userId} AND calendar_id = ${calendarId}
  `;
  if (membership.length === 0) return error("Not a member of this calendar", 403);

  await db`
    DELETE FROM event_reactions
    WHERE event_id = ${id} AND user_id = ${userId} AND emoji = ${decodeURIComponent(emoji)}
  `;

  broadcastToCalendar(calendarId, {
    type: "reaction_update",
    event_id: id,
    calendar_id: calendarId,
  });

  return json({ message: "Reaction removed" });
}
