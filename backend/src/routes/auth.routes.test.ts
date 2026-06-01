import { describe, test, expect, mock, beforeEach } from "bun:test";

// ── Mocks ────────────────────────────────────────────────────────────────────

const mockDb = mock((): Promise<Record<string, unknown>[]> => Promise.resolve([]));
mock.module("../db/client", () => ({ default: mockDb }));
mock.module("../services/email", () => ({
  sendVerificationEmail: mock(() => Promise.resolve()),
  sendPasswordResetEmail: mock(() => Promise.resolve()),
}));
mock.module("../services/google_calendar", () => ({
  generateCalendarConnectUrl: mock(() => Promise.resolve("https://accounts.google.com/o/oauth2/auth?stub")),
  handleCalendarCallback: mock(() => Promise.resolve()),
}));

import { register, login, getMe, updateNotificationType } from "./auth";
import type { RequestContext } from "../types";

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeCtx(body: unknown, user?: { sub: string; email: string; name: string }): RequestContext {
  return {
    req: new Request("http://localhost/auth", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    params: {},
    query: {},
    user,
  };
}

const fakeUser = {
  id: "user-uuid-1",
  email: "alice@example.com",
  name: "Alice",
  color: "#6C63FF",
  notification_type: "email",
  email_verified: false,
  password_hash: "hashed",
};

beforeEach(() => mockDb.mockReset());

// ── register ─────────────────────────────────────────────────────────────────

describe("register", () => {
  test("returns 400 when email is missing", async () => {
    const ctx = makeCtx({ password: "secret123", name: "Alice" });
    const res = await register(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("required");
  });

  test("returns 400 when password is missing", async () => {
    const ctx = makeCtx({ email: "a@b.com", name: "Alice" });
    const res = await register(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("required");
  });

  test("returns 400 when name is missing", async () => {
    const ctx = makeCtx({ email: "a@b.com", password: "secret123" });
    const res = await register(ctx);
    expect(res.status).toBe(400);
  });

  test("returns 400 when password is too short", async () => {
    const ctx = makeCtx({ email: "a@b.com", password: "abc", name: "Alice" });
    const res = await register(ctx);
    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("6 characters");
  });

  test("returns 409 when email already exists", async () => {
    mockDb.mockResolvedValueOnce([{ id: "existing-id" }]); // email taken
    const ctx = makeCtx({ email: "alice@example.com", password: "secret123", name: "Alice" });
    const res = await register(ctx);
    expect(res.status).toBe(409);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("already in use");
  });

  test("returns 201 with token and user on success", async () => {
    mockDb
      .mockResolvedValueOnce([])                                 // email not taken
      .mockResolvedValueOnce([{ count: 0 }])                    // user count for color
      .mockResolvedValueOnce([fakeUser]);                        // INSERT RETURNING
    const ctx = makeCtx({ email: "alice@example.com", password: "secret123", name: "Alice" });
    const res = await register(ctx);
    expect(res.status).toBe(201);
    const body = await res.json() as { token: string; user: typeof fakeUser };
    expect(typeof body.token).toBe("string");
    expect(body.token.length).toBeGreaterThan(10);
    expect(body.user.email).toBe("alice@example.com");
    expect(body.user.email_verified).toBe(false);
  });

  test("defaults notification_type to email", async () => {
    mockDb
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ count: 0 }])
      .mockResolvedValueOnce([{ ...fakeUser, notification_type: "email" }]);
    const ctx = makeCtx({ email: "a@b.com", password: "secret123", name: "Alice" });
    const res = await register(ctx);
    const body = await res.json() as { user: { notification_type: string } };
    expect(body.user.notification_type).toBe("email");
  });

  test("accepts push as notification_type", async () => {
    mockDb
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ count: 0 }])
      .mockResolvedValueOnce([{ ...fakeUser, notification_type: "push" }]);
    const ctx = makeCtx({ email: "a@b.com", password: "secret123", name: "Alice", notification_type: "push" });
    const res = await register(ctx);
    const body = await res.json() as { user: { notification_type: string } };
    expect(body.user.notification_type).toBe("push");
  });
});

// ── login ─────────────────────────────────────────────────────────────────────

describe("login", () => {
  test("returns 400 when email is missing", async () => {
    const ctx = makeCtx({ password: "secret123" });
    const res = await login(ctx);
    expect(res.status).toBe(400);
  });

  test("returns 400 when password is missing", async () => {
    const ctx = makeCtx({ email: "alice@example.com" });
    const res = await login(ctx);
    expect(res.status).toBe(400);
  });

  test("returns 401 when user does not exist", async () => {
    mockDb.mockResolvedValueOnce([]); // user not found
    const ctx = makeCtx({ email: "ghost@example.com", password: "secret123" });
    const res = await login(ctx);
    expect(res.status).toBe(401);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("Invalid credentials");
  });

  test("returns 401 for wrong password", async () => {
    const hash = await Bun.password.hash("correctpassword");
    mockDb.mockResolvedValueOnce([{ ...fakeUser, password_hash: hash }]);
    const ctx = makeCtx({ email: "alice@example.com", password: "wrongpassword" });
    const res = await login(ctx);
    expect(res.status).toBe(401);
  });

  test("returns 200 with token and user for valid credentials", async () => {
    const hash = await Bun.password.hash("secret123");
    mockDb.mockResolvedValueOnce([{ ...fakeUser, password_hash: hash }]);
    const ctx = makeCtx({ email: "alice@example.com", password: "secret123" });
    const res = await login(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { token: string; user: typeof fakeUser };
    expect(typeof body.token).toBe("string");
    expect(body.user.email).toBe("alice@example.com");
  });

  test("error message is identical for wrong email and wrong password (no enumeration)", async () => {
    // Both cases should return the same 401 error so attackers can't enumerate accounts
    mockDb.mockResolvedValueOnce([]); // user not found
    const r1 = await login(makeCtx({ email: "ghost@example.com", password: "x" }));
    const b1 = await r1.json() as { error: string };

    const hash = await Bun.password.hash("correctpw");
    mockDb.mockResolvedValueOnce([{ ...fakeUser, password_hash: hash }]);
    const r2 = await login(makeCtx({ email: "alice@example.com", password: "wrongpw" }));
    const b2 = await r2.json() as { error: string };

    expect(r1.status).toBe(401);
    expect(r2.status).toBe(401);
    expect(b1.error).toBe(b2.error);
  });
});

// ── getMe ─────────────────────────────────────────────────────────────────────

describe("getMe", () => {
  test("returns user data from DB", async () => {
    mockDb
      .mockResolvedValueOnce([fakeUser])  // user lookup
      .mockResolvedValueOnce([]);         // google_calendar_tokens
    const ctx = makeCtx({}, { sub: fakeUser.id, email: fakeUser.email, name: fakeUser.name });
    const res = await getMe(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as typeof fakeUser;
    expect(body.email).toBe("alice@example.com");
  });

  test("returns has_google_calendar true when token row exists", async () => {
    mockDb
      .mockResolvedValueOnce([fakeUser])
      .mockResolvedValueOnce([{ user_id: fakeUser.id }]); // token row exists
    const ctx = makeCtx({}, { sub: fakeUser.id, email: fakeUser.email, name: fakeUser.name });
    const res = await getMe(ctx);
    const body = await res.json() as { has_google_calendar: boolean };
    expect(body.has_google_calendar).toBe(true);
  });

  test("returns has_google_calendar false when no token row", async () => {
    mockDb
      .mockResolvedValueOnce([fakeUser])
      .mockResolvedValueOnce([]); // no token row
    const ctx = makeCtx({}, { sub: fakeUser.id, email: fakeUser.email, name: fakeUser.name });
    const res = await getMe(ctx);
    const body = await res.json() as { has_google_calendar: boolean };
    expect(body.has_google_calendar).toBe(false);
  });
});

// ── updateNotificationType ────────────────────────────────────────────────────

describe("updateNotificationType", () => {
  test("returns 400 for invalid notification_type", async () => {
    const ctx = makeCtx({ notification_type: "sms" }, { sub: fakeUser.id, email: fakeUser.email, name: fakeUser.name });
    const res = await updateNotificationType(ctx);
    expect(res.status).toBe(400);
  });

  test("accepts push and persists it", async () => {
    mockDb.mockResolvedValueOnce([]); // UPDATE
    const ctx = makeCtx({ notification_type: "push" }, { sub: fakeUser.id, email: fakeUser.email, name: fakeUser.name });
    const res = await updateNotificationType(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { notification_type: string };
    expect(body.notification_type).toBe("push");
  });

  test("accepts email and persists it", async () => {
    mockDb.mockResolvedValueOnce([]);
    const ctx = makeCtx({ notification_type: "email" }, { sub: fakeUser.id, email: fakeUser.email, name: fakeUser.name });
    const res = await updateNotificationType(ctx);
    expect(res.status).toBe(200);
    const body = await res.json() as { notification_type: string };
    expect(body.notification_type).toBe("email");
  });
});
