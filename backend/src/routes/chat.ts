import db from "../db/client";
import { json, error } from "../router";
import type { RequestContext } from "../types";
import { broadcastToCalendar } from "../ws/websocket";
import { sendChatMessageNotification } from "../services/email";

// In-memory cooldown: one email burst per calendar every 10 minutes.
const lastChatEmailSent = new Map<string, number>(); // calendarId → timestamp ms
const CHAT_EMAIL_COOLDOWN_MS = 10 * 60 * 1000;

interface ChatMessageRow {
  id: string;
  calendar_id: string;
  user_id: string;
  sender_name: string;
  sender_avatar_url: string | null;
  sender_color: string | null;
  content: string | null;
  deleted_at: Date | null;
  created_at: Date;
}

function formatMessage(row: ChatMessageRow) {
  const isDeleted = row.deleted_at !== null;
  return {
    id: row.id,
    calendar_id: row.calendar_id,
    user_id: row.user_id,
    sender_name: row.sender_name,
    sender_avatar_url: row.sender_avatar_url ?? null,
    sender_color: row.sender_color ?? "#6C63FF",
    content: isDeleted ? null : row.content,
    is_deleted: isDeleted,
    created_at: row.created_at,
  };
}

async function assertMember(calendarId: string, userId: string): Promise<boolean> {
  const rows = await db`
    SELECT 1 FROM calendar_members
    WHERE calendar_id = ${calendarId} AND user_id = ${userId}
    LIMIT 1
  `;
  return rows.length > 0;
}

// GET /calendars/:id/messages
export async function getMessages(ctx: RequestContext): Promise<Response> {
  const calendarId = ctx.params.id;
  const userId = ctx.user!.sub;

  if (!(await assertMember(calendarId, userId))) {
    return error("Not a member of this calendar", 403);
  }

  const before = ctx.query.before as string | undefined;

  const rows = before
    ? await db<ChatMessageRow[]>`
        SELECT cm.id, cm.calendar_id, cm.user_id,
               u.name AS sender_name, u.avatar_url AS sender_avatar_url,
               u.color AS sender_color, cm.content, cm.deleted_at, cm.created_at
        FROM chat_messages cm
        JOIN users u ON u.id = cm.user_id
        WHERE cm.calendar_id = ${calendarId}
          AND cm.created_at < ${before}::timestamptz
        ORDER BY cm.created_at DESC
        LIMIT 50
      `
    : await db<ChatMessageRow[]>`
        SELECT cm.id, cm.calendar_id, cm.user_id,
               u.name AS sender_name, u.avatar_url AS sender_avatar_url,
               u.color AS sender_color, cm.content, cm.deleted_at, cm.created_at
        FROM chat_messages cm
        JOIN users u ON u.id = cm.user_id
        WHERE cm.calendar_id = ${calendarId}
        ORDER BY cm.created_at DESC
        LIMIT 50
      `;

  return json(rows.map(formatMessage));
}

// POST /calendars/:id/messages
export async function postMessage(ctx: RequestContext): Promise<Response> {
  const calendarId = ctx.params.id;
  const userId = ctx.user!.sub;

  if (!(await assertMember(calendarId, userId))) {
    return error("Not a member of this calendar", 403);
  }

  const body = await ctx.req.json().catch(() => ({})) as { content?: unknown };
  const content = typeof body.content === "string" ? body.content.trim() : "";

  if (!content) return error("content is required", 400);
  if (content.length > 2000) return error("content too long (max 2000 chars)", 400);

  const [senderRow] = await db<{ name: string; avatar_url: string | null; color: string }[]>`
    SELECT name, avatar_url, color FROM users WHERE id = ${userId}
  `;
  if (!senderRow) return error("User not found", 404);

  const [inserted] = await db<ChatMessageRow[]>`
    INSERT INTO chat_messages (calendar_id, user_id, content)
    VALUES (${calendarId}, ${userId}, ${content})
    RETURNING id, calendar_id, user_id, content, deleted_at, created_at
  `;

  const message = {
    id: inserted.id,
    calendar_id: inserted.calendar_id,
    user_id: inserted.user_id,
    sender_name: senderRow.name,
    sender_avatar_url: senderRow.avatar_url ?? null,
    sender_color: senderRow.color ?? "#6C63FF",
    content: inserted.content,
    is_deleted: false,
    created_at: inserted.created_at,
  };

  broadcastToCalendar(calendarId, {
    type: "chat_message",
    calendar_id: calendarId,
    message,
  });

  // Email cooldown: notify email-preference members at most once per 10 min
  const now = Date.now();
  const last = lastChatEmailSent.get(calendarId) ?? 0;
  if (now - last > CHAT_EMAIL_COOLDOWN_MS) {
    lastChatEmailSent.set(calendarId, now);
    const emailRecipients = await db<{ email: string }[]>`
      SELECT u.email FROM calendar_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.calendar_id = ${calendarId}
        AND u.id != ${userId}
        AND u.email_verified = true
        AND u.notification_type = 'email'
    `;
    if (emailRecipients.length > 0) {
      const calRow = await db<{ name: string }[]>`SELECT name FROM calendars WHERE id = ${calendarId}`;
      sendChatMessageNotification(
        calRow[0]?.name as string,
        senderRow.name,
        content,
        emailRecipients.map(r => r.email),
      ).catch(console.error);
    }
  }

  return json(message);
}

// DELETE /calendars/:id/messages/:msgId
export async function deleteMessage(ctx: RequestContext): Promise<Response> {
  const calendarId = ctx.params.id;
  const msgId = ctx.params.msgId;
  const userId = ctx.user!.sub;

  const [msg] = await db<{ user_id: string; deleted_at: Date | null }[]>`
    SELECT user_id, deleted_at FROM chat_messages
    WHERE id = ${msgId} AND calendar_id = ${calendarId}
    LIMIT 1
  `;

  if (!msg) return error("Message not found", 404);
  if (msg.user_id !== userId) return error("Forbidden", 403);
  if (msg.deleted_at !== null) return json({ success: true }); // already deleted

  await db`
    UPDATE chat_messages SET deleted_at = now()
    WHERE id = ${msgId}
  `;

  broadcastToCalendar(calendarId, {
    type: "chat_message_deleted",
    calendar_id: calendarId,
    message_id: msgId,
  });

  return json({ success: true });
}
