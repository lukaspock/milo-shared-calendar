import { describe, test, expect, mock, beforeEach } from "bun:test";

// ── Mocks ────────────────────────────────────────────────────────────────────

const mockDb = mock(() => Promise.resolve([]));
mock.module("../db/client", () => ({ default: mockDb }));

const mockBroadcast = mock(() => {});
mock.module("../ws/websocket", () => ({ broadcastToCalendar: mockBroadcast }));

import { checkAndSendReminders, _resetRemindedEvents } from "./reminder.service";

// Plain spy — avoids Bun mock() live-binding issues when passing as argument.
let emailCalls: unknown[][] = [];
const mockSendReminderEmail = async (...args: unknown[]) => { emailCalls.push(args); };

beforeEach(() => {
  mockDb.mockReset();
  mockBroadcast.mockReset();
  emailCalls = [];
  _resetRemindedEvents();
});

const upcomingEvent = {
  id: "event-uuid-1",
  title: "Team Standup",
  start_time: new Date(Date.now() + 28 * 60 * 1000),
  calendar_id: "cal-uuid-1",
  calendar_name: "Work",
};

describe("checkAndSendReminders", () => {
  test("does nothing when no upcoming events", async () => {
    mockDb.mockResolvedValueOnce([]);
    await checkAndSendReminders(mockSendReminderEmail);
    expect(mockBroadcast).not.toHaveBeenCalled();
    expect(emailCalls.length).toBe(0);
  });

  test("broadcasts WS reminder for each upcoming event", async () => {
    mockDb
      .mockResolvedValueOnce([upcomingEvent])
      .mockResolvedValueOnce([]);
    await checkAndSendReminders(mockSendReminderEmail);
    expect(mockBroadcast).toHaveBeenCalledTimes(1);
    const [calId, msg] = mockBroadcast.mock.calls[0] as [string, Record<string, unknown>];
    expect(calId).toBe("cal-uuid-1");
    expect(msg.type).toBe("event_reminder");
    expect(msg.event_title).toBe("Team Standup");
  });

  test("sends reminder email to verified email-notification members", async () => {
    mockDb
      .mockResolvedValueOnce([upcomingEvent])
      .mockResolvedValueOnce([{ email: "alice@test.com" }, { email: "bob@test.com" }]);
    await checkAndSendReminders(mockSendReminderEmail);
    expect(emailCalls.length).toBe(1);
    const args = emailCalls[0][0] as { memberEmails: string[] };
    expect(args.memberEmails).toContain("alice@test.com");
    expect(args.memberEmails).toContain("bob@test.com");
  });

  test("does not send email when no members have email notifications", async () => {
    mockDb
      .mockResolvedValueOnce([upcomingEvent])
      .mockResolvedValueOnce([]);
    await checkAndSendReminders(mockSendReminderEmail);
    expect(mockBroadcast).toHaveBeenCalled();
    expect(emailCalls.length).toBe(0);
  });

  test("skips events already reminded (deduplication)", async () => {
    mockDb
      .mockResolvedValueOnce([upcomingEvent])
      .mockResolvedValueOnce([]);
    await checkAndSendReminders(mockSendReminderEmail);
    const firstCount = mockBroadcast.mock.calls.length;

    mockDb.mockResolvedValueOnce([upcomingEvent]);
    await checkAndSendReminders(mockSendReminderEmail);
    expect(mockBroadcast.mock.calls.length).toBe(firstCount);
  });

  test("handles multiple events in one check", async () => {
    const event2 = { ...upcomingEvent, id: "event-uuid-2", title: "Design Review", calendar_id: "cal-uuid-2" };
    mockDb
      .mockResolvedValueOnce([upcomingEvent, event2])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([]);
    await checkAndSendReminders(mockSendReminderEmail);
    expect(mockBroadcast).toHaveBeenCalledTimes(2);
  });
});
