import { describe, test, expect, mock, beforeEach } from "bun:test";

// ── Mocks ────────────────────────────────────────────────────────────────────

const mockDb = mock((): Promise<Record<string, unknown>[]> => Promise.resolve([]));
mock.module("../db/client", () => ({ default: mockDb }));
mock.module("../ws/websocket", () => ({ broadcastToCalendar: mock(() => {}) }));
mock.module("../services/email", () => ({
  sendChatMessageNotification: mock(() => Promise.resolve()),
}));

import { getMessages, postMessage, deleteMessage } from "./chat";
import type { RequestContext } from "../types";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeCtx(
  userId: string,
  body: unknown,
  params: Record<string, string> = {},
  query: Record<string, string> = {},
  method = "POST",
): RequestContext {
  return {
    req: new Request("http://localhost/calendars/cal-1/messages", {
      method,
      headers: { "Content-Type": "application/json" },
      body: method === "GET" ? null : JSON.stringify(body),
    }),
    params,
    query,
    user: { sub: userId, email: "user@test.com", name: "Test" },
  };
}

const CALENDAR_ID = "cal-uuid-1";
const MSG_ID = "msg-uuid-1";
const USER_ID = "user-uuid-1";
const OTHER_USER_ID = "user-uuid-2";

const fakeMessage = {
  id: MSG_ID,
  calendar_id: CALENDAR_ID,
  user_id: USER_ID,
  content: "Hello!",
  deleted_at: null,
  created_at: new Date("2026-06-10T10:00:00Z"),
};

const fakeSender = {
  name: "Alice",
  avatar_url: null,
  color: "#6C63FF",
};

beforeEach(() => mockDb.mockReset());

// ── getMessages ───────────────────────────────────────────────────────────────

describe("getMessages", () => {
  test("returns 403 when not a member", async () => {
    mockDb.mockResolvedValueOnce([]); // member check returns empty
    const ctx = makeCtx(USER_ID, null, { id: CALENDAR_ID }, {}, "GET");
    const res = await getMessages(ctx);
    expect(res.status).toBe(403);
  });

  test("returns messages for calendar member", async () => {
    mockDb.mockResolvedValueOnce([{ "1": 1 }]); // member check
    mockDb.mockResolvedValueOnce([
      { ...fakeMessage, sender_name: "Alice", sender_avatar_url: null, sender_color: "#6C63FF" },
    ]); // messages query
    const ctx = makeCtx(USER_ID, null, { id: CALENDAR_ID }, {}, "GET");
    const res = await getMessages(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as unknown[];
    expect(Array.isArray(body)).toBe(true);
    expect(body).toHaveLength(1);
  });
});

// ── postMessage ───────────────────────────────────────────────────────────────

describe("postMessage", () => {
  test("returns 403 when not a member", async () => {
    mockDb.mockResolvedValueOnce([]); // member check
    const ctx = makeCtx(USER_ID, { content: "Hi" }, { id: CALENDAR_ID });
    const res = await postMessage(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 400 when content is empty", async () => {
    mockDb.mockResolvedValueOnce([{ "1": 1 }]); // member check
    const ctx = makeCtx(USER_ID, { content: "" }, { id: CALENDAR_ID });
    const res = await postMessage(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("required");
  });

  test("returns 400 when content exceeds 2000 chars", async () => {
    mockDb.mockResolvedValueOnce([{ "1": 1 }]); // member check
    const ctx = makeCtx(USER_ID, { content: "x".repeat(2001) }, { id: CALENDAR_ID });
    const res = await postMessage(ctx);
    expect(res.status).toBe(400);
  });

  test("returns 200 with message on success", async () => {
    mockDb.mockResolvedValueOnce([{ "1": 1 }]); // member check
    mockDb.mockResolvedValueOnce([fakeSender]); // sender lookup
    mockDb.mockResolvedValueOnce([fakeMessage]); // INSERT RETURNING
    mockDb.mockResolvedValueOnce([]); // email recipients
    const ctx = makeCtx(USER_ID, { content: "Hello!" }, { id: CALENDAR_ID });
    const res = await postMessage(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { id: string; content: string; is_deleted: boolean };
    expect(body.id).toBe(MSG_ID);
    expect(body.content).toBe("Hello!");
    expect(body.is_deleted).toBe(false);
  });
});

// ── deleteMessage ─────────────────────────────────────────────────────────────

describe("deleteMessage", () => {
  test("returns 403 when message belongs to another user", async () => {
    mockDb.mockResolvedValueOnce([{ user_id: OTHER_USER_ID, deleted_at: null }]);
    const ctx = makeCtx(USER_ID, null, { id: CALENDAR_ID, msgId: MSG_ID }, {}, "DELETE");
    const res = await deleteMessage(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 404 when message does not exist", async () => {
    mockDb.mockResolvedValueOnce([]); // no message found
    const ctx = makeCtx(USER_ID, null, { id: CALENDAR_ID, msgId: MSG_ID }, {}, "DELETE");
    const res = await deleteMessage(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 200 and soft-deletes own message", async () => {
    mockDb.mockResolvedValueOnce([{ user_id: USER_ID, deleted_at: null }]); // message lookup
    mockDb.mockResolvedValueOnce([]); // UPDATE
    const ctx = makeCtx(USER_ID, null, { id: CALENDAR_ID, msgId: MSG_ID }, {}, "DELETE");
    const res = await deleteMessage(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { success: boolean };
    expect(body.success).toBe(true);
  });
});
