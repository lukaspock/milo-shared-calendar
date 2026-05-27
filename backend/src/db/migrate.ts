import db from "./client";

export async function runMigrations(): Promise<void> {
  await db`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS verification_token TEXT,
      ADD COLUMN IF NOT EXISTS verification_expires_at TIMESTAMP
  `;
  console.log("[db] migrations applied");
}
