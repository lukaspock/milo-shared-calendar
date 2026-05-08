import db from "../db/client";
import { signToken } from "../middleware/auth.middleware";
import { json, error } from "../router";
import type { RequestContext } from "../types";

export async function register(ctx: RequestContext): Promise<Response> {
  let body: { email?: string; password?: string; name?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { email, password, name } = body;
  if (!email || !password || !name) {
    return error("email, password and name are required");
  }
  if (password.length < 6) {
    return error("Password must be at least 6 characters");
  }

  // Check if email already exists
  const existing = await db`SELECT id FROM users WHERE email = ${email}`;
  if (existing.length > 0) {
    return error("Email already in use", 409);
  }

  const passwordHash = await Bun.password.hash(password);

  // Assign a color from a fixed palette based on count
  const colors = ["#6C63FF", "#FF6584", "#43B89C", "#F5A623", "#4A90E2", "#E74C3C", "#2ECC71", "#9B59B6"];
  const countResult = await db`SELECT COUNT(*) AS count FROM users`;
  const idx = Number(countResult[0].count) % colors.length;
  const color = colors[idx];

  const users = await db`
    INSERT INTO users (email, password_hash, name, color)
    VALUES (${email}, ${passwordHash}, ${name}, ${color})
    RETURNING id, email, name, color, created_at
  `;
  const user = users[0];

  const token = await signToken({ sub: user.id, email: user.email, name: user.name });

  return json({ token, user: { id: user.id, email: user.email, name: user.name, color: user.color } }, 201);
}

export async function login(ctx: RequestContext): Promise<Response> {
  let body: { email?: string; password?: string };
  try {
    body = await ctx.req.json();
  } catch {
    return error("Invalid JSON body");
  }

  const { email, password } = body;
  if (!email || !password) {
    return error("email and password are required");
  }

  const users = await db`SELECT * FROM users WHERE email = ${email}`;
  if (users.length === 0) {
    return error("Invalid credentials", 401);
  }

  const user = users[0];
  const valid = await Bun.password.verify(password, user.password_hash);
  if (!valid) {
    return error("Invalid credentials", 401);
  }

  const token = await signToken({ sub: user.id, email: user.email, name: user.name });

  return json({ token, user: { id: user.id, email: user.email, name: user.name, color: user.color } });
}
