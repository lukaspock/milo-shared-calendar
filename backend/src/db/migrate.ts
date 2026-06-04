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

  // Recurring events: simple rule ('daily'|'weekly'|'monthly') + optional end date
  await db`
    ALTER TABLE events
      ADD COLUMN IF NOT EXISTS recurrence_rule TEXT,
      ADD COLUMN IF NOT EXISTS recurrence_end  DATE
  `;

  // Password reset: single-use token + 1-hour expiry, cleared after use
  await db`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS reset_token TEXT,
      ADD COLUMN IF NOT EXISTS reset_expires_at TIMESTAMP
  `;

  // parent_event_id: links recurring instances back to the root event
  // ON DELETE CASCADE so deleting the root removes all instances automatically
  await db`
    ALTER TABLE events
      ADD COLUMN IF NOT EXISTS parent_event_id UUID REFERENCES events(id) ON DELETE CASCADE
  `;

  // Custom vote options per poll (replaces hardcoded yes/no/maybe)
  await db`
    CREATE TABLE IF NOT EXISTS poll_vote_options (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      poll_id    UUID REFERENCES event_polls(id) ON DELETE CASCADE,
      label      TEXT NOT NULL,
      color      TEXT NOT NULL DEFAULT '#6C63FF',
      position   INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT now()
    )
  `;

  // Drop the yes/no/maybe constraint so custom labels can be stored
  await db`ALTER TABLE poll_votes DROP CONSTRAINT IF EXISTS poll_votes_vote_check`;

  // Emoji reactions on events (one row per user+emoji+event)
  await db`
    CREATE TABLE IF NOT EXISTS event_reactions (
      event_id   UUID REFERENCES events(id) ON DELETE CASCADE,
      user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
      emoji      TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT now(),
      PRIMARY KEY (event_id, user_id, emoji)
    )
  `;

  // Profile pictures: Cloudinary URL stored per user
  await db`ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT`;

  // Event icons: a single emoji or short string chosen at creation/edit time
  await db`ALTER TABLE events ADD COLUMN IF NOT EXISTS icon TEXT`;

  console.log("[db] migrations applied");
}
