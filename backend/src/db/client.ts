import { SQL } from "bun";

const db = new SQL(process.env.DATABASE_URL!, {
  // Recycle idle connections after 10 s — shorter than Render's DB idle timeout
  // so we never hold a stale connection that gets force-closed mid-query.
  idleTimeout: 10,
  max: 10,
});

export default db;
