import db from "../db/client";
import { verifyToken } from "../middleware/auth.middleware";
import type { JwtPayload } from "../types";

// Map of calendarId → Set of WebSocket clients subscribed to it
const rooms = new Map<string, Set<ServerWebSocket<WsData>>>();

interface WsData {
  user?: JwtPayload;
  calendarIds: string[];
}

function addToRoom(calendarId: string, ws: ServerWebSocket<WsData>) {
  if (!rooms.has(calendarId)) rooms.set(calendarId, new Set());
  rooms.get(calendarId)!.add(ws);
}

function removeFromRooms(ws: ServerWebSocket<WsData>) {
  for (const [calendarId, clients] of rooms) {
    clients.delete(ws);
    if (clients.size === 0) rooms.delete(calendarId);
  }
}

export function broadcastToCalendar(calendarId: string, payload: unknown, excludeWs?: ServerWebSocket<WsData>) {
  const clients = rooms.get(calendarId);
  if (!clients) return;
  const msg = JSON.stringify(payload);
  for (const ws of clients) {
    if (ws !== excludeWs) {
      ws.send(msg);
    }
  }
}

export const websocketHandler = {
  async open(ws: ServerWebSocket<WsData>) {
    ws.data = { calendarIds: [] };
    console.log("[WS] Client connected");
  },

  async message(ws: ServerWebSocket<WsData>, message: string | Buffer) {
    let parsed: { type: string; token?: string; calendarIds?: string[] };
    try {
      parsed = JSON.parse(message.toString());
    } catch {
      ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
      return;
    }

    if (parsed.type === "auth") {
      if (!parsed.token) {
        ws.send(JSON.stringify({ type: "error", message: "token required" }));
        return;
      }
      try {
        const user = await verifyToken(parsed.token);
        ws.data.user = user;
        ws.send(JSON.stringify({ type: "auth_ok", userId: user.sub }));
      } catch {
        ws.send(JSON.stringify({ type: "error", message: "Invalid token" }));
        ws.close();
      }
      return;
    }

    if (!ws.data.user) {
      ws.send(JSON.stringify({ type: "error", message: "Not authenticated" }));
      return;
    }

    if (parsed.type === "subscribe") {
      const calendarIds = parsed.calendarIds ?? [];
      // Verify user is member of each calendar before subscribing
      for (const calendarId of calendarIds) {
        const membership = await db`
          SELECT 1 FROM calendar_members 
          WHERE user_id = ${ws.data.user.sub} AND calendar_id = ${calendarId}
        `;
        if (membership.length > 0) {
          addToRoom(calendarId, ws);
          ws.data.calendarIds.push(calendarId);
        }
      }
      ws.send(JSON.stringify({ type: "subscribed", calendarIds: ws.data.calendarIds }));
    }
  },

  close(ws: ServerWebSocket<WsData>) {
    removeFromRooms(ws);
    console.log("[WS] Client disconnected");
  },
};

// Start listening to PostgreSQL NOTIFY on calendar_events channel
export async function startNotifyListener() {
  const postgres = (await import("postgres")).default;
  const sql = postgres(process.env.DATABASE_URL!);

  await sql.listen("calendar_events", async (payload: string) => {
    try {
      const data = JSON.parse(payload) as {
        op: string;
        id: string;
        calendar_id: string;
      };

      // Fetch the full event data if it wasn't deleted
      if (data.op === "DELETE") {
        broadcastToCalendar(data.calendar_id, {
          type: "event_deleted",
          event_id: data.id,
          calendar_id: data.calendar_id,
        });
      } else {
        // Use Bun's SQL for the query to stay consistent
        const events = await db`
          SELECT e.*, u.name AS creator_name, u.color AS creator_color
          FROM events e
          LEFT JOIN users u ON u.id = e.created_by
          WHERE e.id = ${data.id}
        `;
        if (events.length > 0) {
          broadcastToCalendar(data.calendar_id, {
            type: data.op === "INSERT" ? "event_created" : "event_updated",
            event: events[0],
          });
        }
      }
    } catch (e) {
      console.error("[NOTIFY] Failed to process notification:", e);
    }
  });

  console.log(
    "[WS] Listening for PostgreSQL NOTIFY on channel 'calendar_events'"
  );
}
