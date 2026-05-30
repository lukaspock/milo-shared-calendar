import { describe, test, expect } from "bun:test";
import { Router, json, error } from "./router";
import type { RequestContext } from "./types";

// ── json() / error() helpers ────────────────────────────────────────────────

describe("json()", () => {
  test("returns 200 by default", () => {
    const res = json({ ok: true });
    expect(res.status).toBe(200);
  });

  test("serialises the body as JSON", async () => {
    const res = json({ hello: "world" });
    const body = await res.json();
    expect(body).toEqual({ hello: "world" });
  });

  test("uses the provided status code", () => {
    const res = json({}, 201);
    expect(res.status).toBe(201);
  });

  test("sets Content-Type to application/json", () => {
    const res = json({});
    expect(res.headers.get("Content-Type")).toContain("application/json");
  });
});

describe("error()", () => {
  test("wraps message in { error } shape", async () => {
    const res = error("not found", 404);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("not found");
    expect(res.status).toBe(404);
  });

  test("defaults to status 400", () => {
    const res = error("bad");
    expect(res.status).toBe(400);
  });
});

// ── Router ──────────────────────────────────────────────────────────────────

describe("Router", () => {
  function makeReq(method: string, path: string): Request {
    return new Request(`http://localhost${path}`, { method });
  }

  test("matches a static GET route and calls handler", async () => {
    const router = new Router();
    router.get("/health", async () => json({ status: "ok" }));

    const res = await router.handle(makeReq("GET", "/health"));
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string };
    expect(body.status).toBe("ok");
  });

  test("returns 404 for unregistered routes", async () => {
    const router = new Router();
    const res = await router.handle(makeReq("GET", "/unknown"));
    expect(res.status).toBe(404);
  });

  test("extracts named URL params", async () => {
    const router = new Router();
    let captured: Record<string, string> = {};
    router.get("/users/:id", async (ctx: RequestContext) => {
      captured = ctx.params;
      return json({});
    });

    await router.handle(makeReq("GET", "/users/abc-123"));
    expect(captured.id).toBe("abc-123");
  });

  test("handles multiple params in one path", async () => {
    const router = new Router();
    let captured: Record<string, string> = {};
    router.delete("/calendars/:calId/members/:userId", async (ctx) => {
      captured = ctx.params;
      return json({});
    });

    await router.handle(makeReq("DELETE", "/calendars/cal-1/members/usr-2"));
    expect(captured.calId).toBe("cal-1");
    expect(captured.userId).toBe("usr-2");
  });

  test("routes do not cross-match different methods", async () => {
    const router = new Router();
    router.post("/events", async () => json({ created: true }, 201));

    const res = await router.handle(makeReq("GET", "/events"));
    expect(res.status).toBe(404);
  });

  test("OPTIONS preflight returns 204", async () => {
    const router = new Router();
    const res = await router.handle(makeReq("OPTIONS", "/any/path"));
    expect(res.status).toBe(204);
  });

  test("runs middleware and stops if it returns a Response", async () => {
    const router = new Router();
    const rejectMiddleware = async (_ctx: RequestContext): Promise<Response> =>
      error("Forbidden", 403);

    router.get("/protected", async () => json({ secret: true }), [rejectMiddleware]);

    const res = await router.handle(makeReq("GET", "/protected"));
    expect(res.status).toBe(403);
  });

  test("passes ctx through middleware chain to handler", async () => {
    const router = new Router();
    const addHeaderMiddleware = async (ctx: RequestContext): Promise<RequestContext> => ({
      ...ctx,
      user: { sub: "test-user-id", email: "t@t.com", name: "T" },
    });

    let handlerCtx: RequestContext | undefined;
    router.get("/me", async (ctx) => {
      handlerCtx = ctx;
      return json({ id: ctx.user?.sub });
    }, [addHeaderMiddleware]);

    await router.handle(makeReq("GET", "/me"));
    expect(handlerCtx?.user?.sub).toBe("test-user-id");
  });
});
