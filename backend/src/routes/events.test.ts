import { describe, test, expect, mock, beforeEach } from "bun:test";

// ── Mocks ────────────────────────────────────────────────────────────────────

const mockDb = mock((): Promise<Record<string, unknown>[]> => Promise.resolve([]));
mock.module("../db/client", () => ({ default: mockDb }));
mock.module("../ws/websocket", () => ({ broadcastToCalendar: mock(() => {}) }));
mock.module("../services/email", () => ({
  sendEventNotification: mock(() => Promise.resolve()),
}));
mock.module("../services/google_calendar", () => ({
  syncEventCreated: mock(() => Promise.resolve()),
  syncEventUpdated: mock(() => Promise.resolve()),
  syncEventDeleted: mock(() => Promise.resolve()),
}));

import { createEvent, updateEvent, deleteEvent } from "./events";
import type { RequestContext } from "../types";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeCtx(userId: string, body: unknown, params: Record<string, string> = {}): RequestContext {
  return {
    req: new Request("http://localhost/events", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    params,
    query: {},
    user: { sub: userId, email: "user@test.com", name: "Test User" },
  };
}

const CALENDAR_ID = "cal-uuid-1";
const USER_ID = "user-uuid-1";
const OTHER_USER_ID = "user-uuid-2";
const EVENT_ID = "event-uuid-1";

const fakeEvent = {
  id: EVENT_ID,
  calendar_id: CALENDAR_ID,
  created_by: USER_ID,
  title: "Team Sync",
  description: null,
  start_time: new Date("2026-06-01T10:00:00Z"),
  end_time: new Date("2026-06-01T11:00:00Z"),
  color: "#6C63FF",
  recurrence_rule: null,
  recurrence_end: null,
};

// Reset db mock before each test
beforeEach(() => mockDb.mockReset());

// ── createEvent ───────────────────────────────────────────────────────────────

describe("createEvent", () => {
  test("returns 400 when required fields are missing", async () => {
    mockDb.mockResolvedValueOnce([{ "?column?": 1 }]); // membership check
    const ctx = makeCtx(USER_ID, { calendar_id: CALENDAR_ID, title: "X" }); // missing start/end
    const res = await createEvent(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("required");
  });

  test("returns 403 when user is not a calendar member", async () => {
    mockDb.mockResolvedValueOnce([]); // membership → empty
    const ctx = makeCtx(USER_ID, {
      calendar_id: CALENDAR_ID,
      title: "Test",
      start_time: "2026-06-01T10:00:00Z",
      end_time: "2026-06-01T11:00:00Z",
    });
    const res = await createEvent(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 400 for invalid recurrence_rule", async () => {
    const ctx = makeCtx(USER_ID, {
      calendar_id: CALENDAR_ID,
      title: "Test",
      start_time: "2026-06-01T10:00:00Z",
      end_time: "2026-06-01T11:00:00Z",
      recurrence_rule: "hourly",
    });
    const res = await createEvent(ctx);
    expect(res.status).toBe(400);
  });

  test("creates event and returns 201 for valid member", async () => {
    mockDb
      .mockResolvedValueOnce([{ role: "member" }])  // membership
      .mockResolvedValueOnce([{ color: "#6C63FF" }]) // user color
      .mockResolvedValueOnce([fakeEvent])             // INSERT RETURNING
      .mockResolvedValueOnce([{ name: "Test User" }]) // creator name (fire-and-forget)
      .mockResolvedValueOnce([])                      // email members (fire-and-forget)
      .mockResolvedValueOnce([{ name: "Cal" }]);      // calendar name (fire-and-forget)
    const ctx = makeCtx(USER_ID, {
      calendar_id: CALENDAR_ID,
      title: "Team Sync",
      start_time: "2026-06-01T10:00:00Z",
      end_time: "2026-06-01T11:00:00Z",
    });
    const res = await createEvent(ctx);
    expect(res.status).toBe(201);
    const body = await res.json() as typeof fakeEvent;
    expect(body.title).toBe("Team Sync");
  });
});

// ── updateEvent ───────────────────────────────────────────────────────────────

describe("updateEvent", () => {
  test("returns 404 when event does not exist", async () => {
    mockDb.mockResolvedValueOnce([]); // event lookup → empty
    const ctx = makeCtx(USER_ID, { title: "New Title" }, { id: EVENT_ID });
    const res = await updateEvent(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 403 when caller is not a calendar member", async () => {
    mockDb
      .mockResolvedValueOnce([fakeEvent]) // event lookup
      .mockResolvedValueOnce([]);          // membership → empty
    const ctx = makeCtx(OTHER_USER_ID, { title: "X" }, { id: EVENT_ID });
    const res = await updateEvent(ctx);
    expect(res.status).toBe(403);
  });

  test("updates and returns event for calendar member", async () => {
    const updated = { ...fakeEvent, title: "Updated" };
    mockDb
      .mockResolvedValueOnce([fakeEvent])     // event lookup
      .mockResolvedValueOnce([{ role: "member" }]) // membership
      .mockResolvedValueOnce([updated]);      // UPDATE RETURNING
    const ctx = makeCtx(USER_ID, { title: "Updated" }, { id: EVENT_ID });
    const res = await updateEvent(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as typeof updated;
    expect(body.title).toBe("Updated");
  });
});

// ── deleteEvent ───────────────────────────────────────────────────────────────

describe("deleteEvent", () => {
  test("returns 404 when event does not exist", async () => {
    mockDb.mockResolvedValueOnce([]);
    const ctx = makeCtx(USER_ID, {}, { id: EVENT_ID });
    const res = await deleteEvent(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 403 when caller is not a member", async () => {
    mockDb
      .mockResolvedValueOnce([fakeEvent]) // event lookup
      .mockResolvedValueOnce([]);          // membership → empty
    const ctx = makeCtx(OTHER_USER_ID, {}, { id: EVENT_ID });
    const res = await deleteEvent(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 403 when member is neither creator nor owner", async () => {
    const otherEvent = { ...fakeEvent, created_by: OTHER_USER_ID };
    mockDb
      .mockResolvedValueOnce([otherEvent])          // event lookup
      .mockResolvedValueOnce([{ role: "member" }]); // membership (not owner)
    const ctx = makeCtx(USER_ID, {}, { id: EVENT_ID });
    const res = await deleteEvent(ctx);
    expect(res.status).toBe(403);
  });

  test("allows creator to delete their own event", async () => {
    mockDb
      .mockResolvedValueOnce([fakeEvent])           // event lookup (created_by = USER_ID)
      .mockResolvedValueOnce([{ role: "member" }])  // membership
      .mockResolvedValueOnce([]);                   // DELETE
    const ctx = makeCtx(USER_ID, {}, { id: EVENT_ID });
    const res = await deleteEvent(ctx);
    expect(res.status).toBe(200);
  });

  test("allows calendar owner to delete any event", async () => {
    const otherEvent = { ...fakeEvent, created_by: OTHER_USER_ID };
    mockDb
      .mockResolvedValueOnce([otherEvent])         // event lookup
      .mockResolvedValueOnce([{ role: "owner" }])  // membership (owner)
      .mockResolvedValueOnce([]);                  // DELETE
    const ctx = makeCtx(USER_ID, {}, { id: EVENT_ID });
    const res = await deleteEvent(ctx);
    expect(res.status).toBe(200);
  });
});
