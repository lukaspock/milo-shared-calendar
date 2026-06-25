import { describe, test, expect, mock, beforeEach } from "bun:test";

// ── Mocks ────────────────────────────────────────────────────────────────────

const mockDb = mock((): Promise<Record<string, unknown>[]> => Promise.resolve([]));
mock.module("../db/client", () => ({ default: mockDb }));
mock.module("../ws/websocket", () => ({ broadcastToCalendar: mock(() => {}) }));
mock.module("../services/email", () => ({
  sendPollConfirmedNotification: mock(() => Promise.resolve()),
}));
mock.module("../services/google_calendar", () => ({
  syncEventCreated: mock(() => Promise.resolve()),
}));

import { votePoll, confirmPoll, deletePoll } from "./polls";
import type { RequestContext } from "../types";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeCtx(userId: string, body: unknown, params: Record<string, string> = {}): RequestContext {
  return {
    req: new Request("http://localhost/polls", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    params,
    query: {},
    user: { sub: userId, email: "user@test.com", name: "Test" },
  };
}

const CALENDAR_ID = "cal-uuid-1";
const POLL_ID = "poll-uuid-1";
const OPTION_ID = "option-uuid-1";
const USER_ID = "user-uuid-1";
const OTHER_USER_ID = "user-uuid-2";

const fakePoll = {
  id: POLL_ID,
  calendar_id: CALENDAR_ID,
  created_by: USER_ID,
  title: "When should we meet?",
  description: null,
  closed: false,
  confirmed_option_id: null,
};

const fakeOption = {
  id: OPTION_ID,
  poll_id: POLL_ID,
  start_time: new Date("2026-06-01T10:00:00Z"),
  end_time: new Date("2026-06-01T11:00:00Z"),
};

beforeEach(() => mockDb.mockReset());

// ── votePoll ──────────────────────────────────────────────────────────────────

describe("votePoll", () => {
  test("returns 400 when vote value is invalid", async () => {
    const ctx = makeCtx(USER_ID, { option_id: OPTION_ID, vote: "maybe_not" }, { id: POLL_ID });
    mockDb
      .mockResolvedValueOnce([fakePoll])           // poll lookup
      .mockResolvedValueOnce([{ role: "member" }]) // membership (checked before poll_vote_options)
      .mockResolvedValueOnce([]);                  // poll_vote_options → empty (legacy yes/no/maybe mode)
    const res = await votePoll(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("yes, no, or maybe");
  });

  test("returns 404 when poll does not exist", async () => {
    mockDb.mockResolvedValueOnce([]); // poll not found
    const ctx = makeCtx(USER_ID, { option_id: OPTION_ID, vote: "yes" }, { id: POLL_ID });
    const res = await votePoll(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 400 when poll is closed", async () => {
    mockDb.mockResolvedValueOnce([{ ...fakePoll, closed: true }]);
    const ctx = makeCtx(USER_ID, { option_id: OPTION_ID, vote: "yes" }, { id: POLL_ID });
    const res = await votePoll(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("closed");
  });

  test("returns 403 for non-member", async () => {
    mockDb
      .mockResolvedValueOnce([fakePoll]) // poll lookup
      .mockResolvedValueOnce([])         // poll_vote_options → empty
      .mockResolvedValueOnce([]);        // membership → empty
    const ctx = makeCtx(OTHER_USER_ID, { option_id: OPTION_ID, vote: "yes" }, { id: POLL_ID });
    const res = await votePoll(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 404 when option does not belong to poll", async () => {
    mockDb
      .mockResolvedValueOnce([fakePoll])           // poll
      .mockResolvedValueOnce([{ role: "member" }]) // membership (checked before poll_vote_options)
      .mockResolvedValueOnce([])                   // poll_vote_options → empty
      .mockResolvedValueOnce([]);                  // option lookup → empty
    const ctx = makeCtx(USER_ID, { option_id: "wrong-id", vote: "yes" }, { id: POLL_ID });
    const res = await votePoll(ctx);
    expect(res.status).toBe(404);
  });

  test("records vote and returns updated poll", async () => {
    mockDb
      .mockResolvedValueOnce([fakePoll])           // poll
      .mockResolvedValueOnce([{ role: "member" }]) // membership (checked before poll_vote_options)
      .mockResolvedValueOnce([])                   // poll_vote_options → empty
      .mockResolvedValueOnce([fakeOption])          // option lookup
      .mockResolvedValueOnce([])                   // upsert vote
      // assemblePoll queries:
      .mockResolvedValueOnce([fakeOption])          // options
      .mockResolvedValueOnce([])                   // votes
      .mockResolvedValueOnce([])                   // poll_vote_options (assemblePoll)
      .mockResolvedValueOnce([{ name: "Test" }]);  // creator name
    const ctx = makeCtx(USER_ID, { option_id: OPTION_ID, vote: "yes" }, { id: POLL_ID });
    const res = await votePoll(ctx);
    expect(res.status).toBe(200);
  });
});

// ── confirmPoll ───────────────────────────────────────────────────────────────

describe("confirmPoll", () => {
  test("returns 403 when caller is not the poll creator", async () => {
    mockDb.mockResolvedValueOnce([fakePoll]); // poll lookup (created_by = USER_ID)
    const ctx = makeCtx(OTHER_USER_ID, { option_id: OPTION_ID }, { id: POLL_ID });
    const res = await confirmPoll(ctx);
    expect(res.status).toBe(403);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("creator");
  });

  test("returns 400 when poll is already closed", async () => {
    mockDb.mockResolvedValueOnce([{ ...fakePoll, closed: true }]);
    const ctx = makeCtx(USER_ID, { option_id: OPTION_ID }, { id: POLL_ID });
    const res = await confirmPoll(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("closed");
  });

  test("returns 404 when option does not exist", async () => {
    mockDb
      .mockResolvedValueOnce([fakePoll]) // poll
      .mockResolvedValueOnce([]);        // option lookup → empty
    const ctx = makeCtx(USER_ID, { option_id: "bad-id" }, { id: POLL_ID });
    const res = await confirmPoll(ctx);
    expect(res.status).toBe(404);
  });

  test("creates event and closes poll on successful confirm", async () => {
    const createdEvent = {
      id: "event-uuid-new", calendar_id: CALENDAR_ID, created_by: USER_ID,
      title: "When should we meet?", description: null,
      start_time: fakeOption.start_time, end_time: fakeOption.end_time,
      color: "#6C63FF",
    };
    const closedPoll = { ...fakePoll, closed: true, confirmed_option_id: OPTION_ID };
    mockDb
      .mockResolvedValueOnce([fakePoll])             // poll lookup
      .mockResolvedValueOnce([fakeOption])            // option lookup
      .mockResolvedValueOnce([{ color: "#6C63FF" }]) // user color
      .mockResolvedValueOnce([createdEvent])          // INSERT event RETURNING
      .mockResolvedValueOnce([closedPoll])            // UPDATE poll RETURNING
      // assemblePoll:
      .mockResolvedValueOnce([fakeOption])            // options
      .mockResolvedValueOnce([])                     // votes
      .mockResolvedValueOnce([])                     // poll_vote_options (assemblePoll)
      .mockResolvedValueOnce([{ name: "Test" }])     // creator name
      .mockResolvedValueOnce([createdEvent])          // eventWithCreator (broadcast payload)
      // fire-and-forget email:
      .mockResolvedValueOnce([])                     // members
      .mockResolvedValueOnce([{ name: "Cal" }]);     // calendar name
    const ctx = makeCtx(USER_ID, { option_id: OPTION_ID }, { id: POLL_ID });
    const res = await confirmPoll(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { poll: unknown; event: typeof createdEvent };
    expect(body.event.title).toBe("When should we meet?");
  });
});

// ── deletePoll ────────────────────────────────────────────────────────────────

describe("deletePoll", () => {
  test("returns 404 when poll does not exist", async () => {
    mockDb.mockResolvedValueOnce([]);
    const ctx = makeCtx(USER_ID, {}, { id: POLL_ID });
    const res = await deletePoll(ctx);
    expect(res.status).toBe(404);
  });

  test("returns 403 for non-member", async () => {
    mockDb
      .mockResolvedValueOnce([fakePoll]) // poll
      .mockResolvedValueOnce([]);        // membership → empty
    const ctx = makeCtx(OTHER_USER_ID, {}, { id: POLL_ID });
    const res = await deletePoll(ctx);
    expect(res.status).toBe(403);
  });

  test("returns 403 when member is neither creator nor owner", async () => {
    const otherPoll = { ...fakePoll, created_by: OTHER_USER_ID };
    mockDb
      .mockResolvedValueOnce([otherPoll])            // poll
      .mockResolvedValueOnce([{ role: "member" }]); // not owner
    const ctx = makeCtx(USER_ID, {}, { id: POLL_ID });
    const res = await deletePoll(ctx);
    expect(res.status).toBe(403);
  });

  test("allows creator to delete poll", async () => {
    mockDb
      .mockResolvedValueOnce([fakePoll])           // poll (created_by = USER_ID)
      .mockResolvedValueOnce([{ role: "member" }]) // membership
      .mockResolvedValueOnce([]);                  // DELETE
    const ctx = makeCtx(USER_ID, {}, { id: POLL_ID });
    const res = await deletePoll(ctx);
    expect(res.status).toBe(200);
  });

  test("allows calendar owner to delete any poll", async () => {
    const otherPoll = { ...fakePoll, created_by: OTHER_USER_ID };
    mockDb
      .mockResolvedValueOnce([otherPoll])          // poll
      .mockResolvedValueOnce([{ role: "owner" }]) // owner
      .mockResolvedValueOnce([]);                 // DELETE
    const ctx = makeCtx(USER_ID, {}, { id: POLL_ID });
    const res = await deletePoll(ctx);
    expect(res.status).toBe(200);
  });
});
