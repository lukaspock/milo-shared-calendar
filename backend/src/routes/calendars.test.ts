import { describe, test, expect, mock, beforeEach } from "bun:test";

// ── Mocks ────────────────────────────────────────────────────────────────────

const mockDb = mock((): Promise<Record<string, unknown>[]> => Promise.resolve([]));
mock.module("../db/client", () => ({ default: mockDb }));

const mockBroadcast = mock(() => {});
mock.module("../ws/websocket", () => ({ broadcastToCalendar: mockBroadcast }));

import {
  createCalendar,
  joinCalendar,
  listCalendars,
  listMembers,
  removeMember,
  deleteCalendar,
  leaveCalendar,
} from "./calendars";
import type { RequestContext } from "../types";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeCtx(
  body: unknown,
  userId: string,
  params: Record<string, string> = {},
): RequestContext {
  return {
    req: new Request("http://localhost/calendars", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    params,
    query: {},
    user: { sub: userId, email: "user@test.com", name: "Test User" },
  };
}

const USER_ID = "user-uuid-1";
const OTHER_USER_ID = "user-uuid-2";
const CAL_ID = "cal-uuid-1";

const fakeCalendar = {
  id: CAL_ID,
  name: "Work",
  owner_id: USER_ID,
  invite_code: "ABCD1234",
  created_at: new Date().toISOString(),
};

beforeEach(() => {
  mockDb.mockReset();
  mockBroadcast.mockReset();
});

// ── createCalendar ────────────────────────────────────────────────────────────

describe("createCalendar", () => {
  test("returns 400 when name is missing", async () => {
    const ctx = makeCtx({}, USER_ID);
    const res = await createCalendar(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("required");
  });

  test("returns 400 when name is blank whitespace", async () => {
    const ctx = makeCtx({ name: "   " }, USER_ID);
    const res = await createCalendar(ctx);
    expect(res.status).toBe(400);
  });

  test("returns 201 with calendar and role:owner on success", async () => {
    mockDb
      .mockResolvedValueOnce([])             // invite code uniqueness check
      .mockResolvedValueOnce([fakeCalendar]) // INSERT RETURNING
      .mockResolvedValueOnce([]);            // INSERT member
    const ctx = makeCtx({ name: "Work" }, USER_ID);
    const res = await createCalendar(ctx);
    expect(res.status).toBe(201);
    const body = await res.json() as { role: string; name: string; member_count: number };
    expect(body.role).toBe("owner");
    expect(body.name).toBe("Work");
    expect(body.member_count).toBe(1);
  });
});

// ── joinCalendar ──────────────────────────────────────────────────────────────

describe("joinCalendar", () => {
  test("returns 400 when invite_code is missing", async () => {
    const ctx = makeCtx({}, USER_ID);
    const res = await joinCalendar(ctx);
    expect(res.status).toBe(400);
  });

  test("returns 404 for unknown invite code", async () => {
    mockDb.mockResolvedValueOnce([]); // calendar not found
    const ctx = makeCtx({ invite_code: "ZZZZZZZZ" }, USER_ID);
    const res = await joinCalendar(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 409 when already a member", async () => {
    mockDb
      .mockResolvedValueOnce([fakeCalendar])   // calendar found
      .mockResolvedValueOnce([{ user_id: USER_ID }]); // already member
    const ctx = makeCtx({ invite_code: "ABCD1234" }, USER_ID);
    const res = await joinCalendar(ctx);
    expect(res.status).toBe(409);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("Already a member");
  });

  test("joins successfully and broadcasts member_joined", async () => {
    mockDb
      .mockResolvedValueOnce([fakeCalendar])      // calendar found
      .mockResolvedValueOnce([])                   // not yet a member
      .mockResolvedValueOnce([])                   // INSERT member
      .mockResolvedValueOnce([{ member_count: 2 }]); // count
    const ctx = makeCtx({ invite_code: "ABCD1234" }, OTHER_USER_ID);
    const res = await joinCalendar(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { role: string };
    expect(body.role).toBe("member");
    expect(mockBroadcast).toHaveBeenCalledTimes(1);
    const [calId, msg] = mockBroadcast.mock.calls[0] as [string, { type: string }];
    expect(calId).toBe(CAL_ID);
    expect(msg.type).toBe("member_joined");
  });

  test("invite code lookup is case-insensitive (uppercased before query)", async () => {
    mockDb
      .mockResolvedValueOnce([fakeCalendar])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ member_count: 2 }]);
    // lowercase invite code should still work
    const ctx = makeCtx({ invite_code: "abcd1234" }, OTHER_USER_ID);
    const res = await joinCalendar(ctx);
    expect(res.status).toBe(200);
  });
});

// ── listCalendars ─────────────────────────────────────────────────────────────

describe("listCalendars", () => {
  test("returns empty array when user has no calendars", async () => {
    mockDb.mockResolvedValueOnce([]);
    const ctx = makeCtx({}, USER_ID);
    const res = await listCalendars(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as unknown[];
    expect(body).toEqual([]);
  });

  test("returns list of calendars the user belongs to", async () => {
    mockDb.mockResolvedValueOnce([fakeCalendar, { ...fakeCalendar, id: "cal-2", name: "Family" }]);
    const ctx = makeCtx({}, USER_ID);
    const res = await listCalendars(ctx);
    const body = await res.json() as unknown[];
    expect(body.length).toBe(2);
  });
});

// ── listMembers ───────────────────────────────────────────────────────────────

describe("listMembers", () => {
  test("returns 403 when caller is not a member", async () => {
    mockDb.mockResolvedValueOnce([]); // membership → empty
    const ctx = makeCtx({}, OTHER_USER_ID, { id: CAL_ID });
    const res = await listMembers(ctx);
    expect(res.status).toBe(403);
  });

  test("returns member list for calendar member", async () => {
    const member = { id: USER_ID, email: "u@t.com", name: "U", color: "#fff", role: "owner" };
    mockDb
      .mockResolvedValueOnce([{ role: "owner" }]) // membership
      .mockResolvedValueOnce([member]);            // members query
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID });
    const res = await listMembers(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as typeof member[];
    expect(body[0].email).toBe("u@t.com");
  });
});

// ── removeMember ──────────────────────────────────────────────────────────────

describe("removeMember", () => {
  test("returns 403 when caller is not the owner", async () => {
    mockDb.mockResolvedValueOnce([{ role: "member" }]); // not owner
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID, userId: OTHER_USER_ID });
    const res = await removeMember(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 403 when caller is not a member at all", async () => {
    mockDb.mockResolvedValueOnce([]); // not a member
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID, userId: OTHER_USER_ID });
    const res = await removeMember(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 400 when owner tries to remove themselves", async () => {
    mockDb.mockResolvedValueOnce([{ role: "owner" }]);
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID, userId: USER_ID });
    const res = await removeMember(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("cannot remove yourself");
  });

  test("removes member successfully", async () => {
    mockDb
      .mockResolvedValueOnce([{ role: "owner" }]) // caller is owner
      .mockResolvedValueOnce([]);                  // DELETE
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID, userId: OTHER_USER_ID });
    const res = await removeMember(ctx);
    expect(res.status).toBe(200);
  });
});

// ── deleteCalendar ────────────────────────────────────────────────────────────

describe("deleteCalendar", () => {
  test("returns 403 when caller is not the owner", async () => {
    mockDb.mockResolvedValueOnce([{ role: "member" }]);
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID });
    const res = await deleteCalendar(ctx);
    expect(res.status).toBe(403);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("owner");
  });

  test("returns 403 when caller is not a member", async () => {
    mockDb.mockResolvedValueOnce([]);
    const ctx = makeCtx({}, OTHER_USER_ID, { id: CAL_ID });
    const res = await deleteCalendar(ctx);
    expect(res.status).toBe(403);
  });

  test("deletes calendar when caller is owner", async () => {
    mockDb
      .mockResolvedValueOnce([{ role: "owner" }]) // membership
      .mockResolvedValueOnce([]);                  // DELETE
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID });
    const res = await deleteCalendar(ctx);
    expect(res.status).toBe(200);
  });
});

// ── leaveCalendar ─────────────────────────────────────────────────────────────

describe("leaveCalendar", () => {
  test("returns 404 when caller is not a member", async () => {
    mockDb.mockResolvedValueOnce([]);
    const ctx = makeCtx({}, OTHER_USER_ID, { id: CAL_ID });
    const res = await leaveCalendar(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 400 when owner tries to leave", async () => {
    mockDb.mockResolvedValueOnce([{ role: "owner" }]);
    const ctx = makeCtx({}, USER_ID, { id: CAL_ID });
    const res = await leaveCalendar(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("Delete the calendar instead");
  });

  test("allows member to leave", async () => {
    mockDb
      .mockResolvedValueOnce([{ role: "member" }]) // membership
      .mockResolvedValueOnce([]);                   // DELETE
    const ctx = makeCtx({}, OTHER_USER_ID, { id: CAL_ID });
    const res = await leaveCalendar(ctx);
    expect(res.status).toBe(200);
  });
});
