import type { RequestContext } from "../types";
import { error } from "../router";

interface Window {
  count: number;
  resetAt: number;
}

// Global store: "ip:route-key" → request window
const store = new Map<string, Window>();

// Purge expired entries every 5 minutes so the map doesn't grow indefinitely
setInterval(() => {
  const now = Date.now();
  for (const [key, win] of store) {
    if (now >= win.resetAt) store.delete(key);
  }
}, 5 * 60 * 1000);

/**
 * Returns a rate-limit middleware.
 * @param maxRequests  Requests allowed per window (default: 10)
 * @param windowMs     Window duration in ms (default: 60 000 = 1 minute)
 * @param routeKey     Logical name used in the store key (default: "default")
 */
export function rateLimit(
  maxRequests = 10,
  windowMs = 60_000,
  routeKey = "default"
): (ctx: RequestContext) => Promise<RequestContext | Response> {
  return async (ctx: RequestContext) => {
    const ip =
      ctx.req.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
      ctx.req.headers.get("x-real-ip") ??
      "unknown";

    const key = `${ip}:${routeKey}`;
    const now = Date.now();
    const win = store.get(key);

    if (!win || now >= win.resetAt) {
      store.set(key, { count: 1, resetAt: now + windowMs });
      return ctx;
    }

    if (win.count >= maxRequests) {
      const retryAfter = Math.ceil((win.resetAt - now) / 1000);
      return new Response(JSON.stringify({ error: "Too many requests. Please wait before trying again." }), {
        status: 429,
        headers: {
          "Content-Type": "application/json",
          "Retry-After": String(retryAfter),
        },
      });
    }

    win.count++;
    return ctx;
  };
}

// Pre-built limiter for auth endpoints: 10 attempts per minute per IP
export const authRateLimit = rateLimit(10, 60_000, "auth");
