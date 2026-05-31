import { SignJWT, jwtVerify } from "jose";
import type { JwtPayload, RequestContext } from "../types";
import { error } from "../router";

if (!process.env.JWT_SECRET) {
  throw new Error("JWT_SECRET environment variable is not set. Refusing to start.");
}
const secret = new TextEncoder().encode(process.env.JWT_SECRET);

export async function signToken(payload: JwtPayload): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime("7d")
    .sign(secret);
}

export async function verifyToken(token: string): Promise<JwtPayload> {
  const { payload } = await jwtVerify(token, secret);
  return payload as unknown as JwtPayload;
}

export async function authMiddleware(
  ctx: RequestContext
): Promise<RequestContext | Response> {
  const authHeader = ctx.req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return error("Missing or invalid Authorization header", 401);
  }

  const token = authHeader.slice(7);
  try {
    const user = await verifyToken(token);
    return { ...ctx, user };
  } catch {
    return error("Invalid or expired token", 401);
  }
}
