import type { Handler, RequestContext } from "./types";

type Method = "GET" | "POST" | "PUT" | "DELETE" | "PATCH";

interface Route {
  method: Method;
  pattern: RegExp;
  paramNames: string[];
  handler: Handler;
  middlewares: ((ctx: RequestContext) => Promise<RequestContext | Response>)[];
}

// Lock to a specific origin in production by setting ALLOWED_ORIGIN env var.
// Defaults to "*" for local dev — the Flutter app doesn't send an Origin header
// from native builds, so this only matters for browser/web clients.
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN ?? "*";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export function error(message: string, status = 400): Response {
  return json({ error: message }, status);
}

export class Router {
  private routes: Route[] = [];

  private add(
    method: Method,
    path: string,
    handler: Handler,
    middlewares: ((ctx: RequestContext) => Promise<RequestContext | Response>)[] = []
  ) {
    // Convert /path/:id → regex and extract param names
    const paramNames: string[] = [];
    const regexStr = path
      .replace(/:([^/]+)/g, (_, name) => {
        paramNames.push(name);
        return "([^/]+)";
      })
      .replace(/\//g, "\\/");
    const pattern = new RegExp(`^${regexStr}$`); // nosemgrep: javascript.lang.security.audit.detect-non-literal-regexp.detect-non-literal-regexp
    this.routes.push({ method, pattern, paramNames, handler, middlewares });
  }

  get(path: string, handler: Handler, middlewares?: ((ctx: RequestContext) => Promise<RequestContext | Response>)[]) {
    this.add("GET", path, handler, middlewares);
  }
  post(path: string, handler: Handler, middlewares?: ((ctx: RequestContext) => Promise<RequestContext | Response>)[]) {
    this.add("POST", path, handler, middlewares);
  }
  put(path: string, handler: Handler, middlewares?: ((ctx: RequestContext) => Promise<RequestContext | Response>)[]) {
    this.add("PUT", path, handler, middlewares);
  }
  delete(path: string, handler: Handler, middlewares?: ((ctx: RequestContext) => Promise<RequestContext | Response>)[]) {
    this.add("DELETE", path, handler, middlewares);
  }
  patch(path: string, handler: Handler, middlewares?: ((ctx: RequestContext) => Promise<RequestContext | Response>)[]) {
    this.add("PATCH", path, handler, middlewares);
  }

  async handle(req: Request): Promise<Response> {
    // CORS preflight
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(req.url);
    const pathname = url.pathname;
    const method = req.method as Method;

    console.log(`[HTTP] ${method} ${pathname}`);

    for (const route of this.routes) {
      if (route.method !== method) continue;
      const match = pathname.match(route.pattern);
      if (!match) continue;

      // Build params from regex groups
      const params: Record<string, string> = {};
      route.paramNames.forEach((name, i) => {
        params[name] = match[i + 1];
      });

      // Build query params
      const query: Record<string, string> = {};
      url.searchParams.forEach((value, key) => {
        query[key] = value;
      });

      let ctx: RequestContext = { req, params, query };

      // Run middlewares
      for (const middleware of route.middlewares) {
        const result = await middleware(ctx);
        if (result instanceof Response) return result; // middleware rejected
        ctx = result;
      }

      return route.handler(ctx);
    }

    return error("Not Found", 404);
  }
}
