import postgres from "postgres";

// bun:sql's internal #onClose error bypasses process.on('uncaughtException')
// and crashes the process when Neon/Render scales the DB to zero.
// The npm postgres package handles connection drops gracefully.
const url = process.env.DATABASE_URL ?? "";
const db = postgres(url, {
  // Enable SSL for hosted DBs (Neon, Render) but not for local docker-compose.
  ssl: url.includes("neon.tech") || url.includes("render.com") ? "require" : undefined,
  idle_timeout: 20,
  max_lifetime: 1800,
  max: 10,
  connect_timeout: 30,
});

export default db;
