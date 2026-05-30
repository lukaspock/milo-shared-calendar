import db from "./client";

export async function runMigrations(): Promise<void> {
  await db`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false,
      ADD COLUMN IF NOT EXISTS verification_token TEXT,
      ADD COLUMN IF NOT EXISTS verification_expires_at TIMESTAMP
  `;

  // How a user wants to be notified about new events: 'email' or 'push' (on-device)
  await db`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS notification_type TEXT NOT NULL DEFAULT 'email'
  `;

  // Google Sign-In: nullable password (Google users have no password), unique Google ID
  await db`ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id TEXT`;
  await db`
    DO $$ BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_indexes WHERE tablename = 'users' AND indexname = 'users_google_id_key'
      ) THEN
        CREATE UNIQUE INDEX users_google_id_key ON users(google_id) WHERE google_id IS NOT NULL;
      END IF;
    END $$
  `;
  await db`ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL`;

  // Google Calendar token storage (one row per Google-authenticated user)
  await db`
    CREATE TABLE IF NOT EXISTS google_calendar_tokens (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      access_token TEXT,
      refresh_token TEXT NOT NULL,
      expiry TIMESTAMPTZ,
      google_calendar_id TEXT DEFAULT 'primary'
    )
  `;

  // Mapping SharedCal event IDs → Google Calendar event IDs, per user
  await db`
    CREATE TABLE IF NOT EXISTS google_event_ids (
      event_id UUID REFERENCES events(id) ON DELETE CASCADE,
      user_id  UUID REFERENCES users(id) ON DELETE CASCADE,
      google_event_id TEXT NOT NULL,
      PRIMARY KEY (event_id, user_id)
    )
  `;

  // Password reset: single-use token + 1-hour expiry, cleared after use
  await db`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS reset_token TEXT,
      ADD COLUMN IF NOT EXISTS reset_expires_at TIMESTAMP
  `;

  console.log("[db] migrations applied");
}
