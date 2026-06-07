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

  // Poll icon + color carried through to the confirmed event
  await db`ALTER TABLE event_polls ADD COLUMN IF NOT EXISTS icon TEXT`;
  await db`ALTER TABLE event_polls ADD COLUMN IF NOT EXISTS color TEXT`;

  // Photo memories: opt-in per calendar (toggle at creation time)
  await db`ALTER TABLE calendars ADD COLUMN IF NOT EXISTS photo_mode BOOLEAN NOT NULL DEFAULT FALSE`;

  // Calendar appearance: hue color index (0-7) and optional icon emoji/URL
  await db`ALTER TABLE calendars ADD COLUMN IF NOT EXISTS hue_index INTEGER NOT NULL DEFAULT 0`;
  await db`ALTER TABLE calendars ADD COLUMN IF NOT EXISTS icon TEXT`;

  // Photos uploaded by members for events in photo-mode calendars
  await db`
    CREATE TABLE IF NOT EXISTS event_photos (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_id    UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
      calendar_id UUID NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
      uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
      photo_url   TEXT NOT NULL,
      created_at  TIMESTAMP DEFAULT now()
    )
  `;

  // Cached Google Calendar events imported from members' personal Google Calendars.
  // Deduplicated by iCalUID per calendar; imported_by tracks which members share the event.
  await db`
    CREATE TABLE IF NOT EXISTS imported_gcal_events (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      calendar_id     UUID NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
      ical_uid        TEXT NOT NULL,
      title           TEXT NOT NULL,
      start_time      TIMESTAMPTZ NOT NULL,
      end_time        TIMESTAMPTZ NOT NULL,
      description     TEXT,
      google_event_id TEXT,
      imported_by     JSONB NOT NULL DEFAULT '[]',
      last_synced_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (calendar_id, ical_uid)
    )
  `;

  // Pending Google Calendar OAuth states — persisted so they survive backend restarts
  // (Render Free Tier wipes in-memory state on cold start).
  await db`
    CREATE TABLE IF NOT EXISTS pending_calendar_connects (
      state      TEXT PRIMARY KEY,
      user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at TIMESTAMPTZ NOT NULL
    )
  `;

  // One-time fix: imported_by was stored as a JSONB string (double-encoded via
  // JSON.stringify) instead of a JSONB array. Re-parse any rows where
  // jsonb_typeof(imported_by) = 'string' so they become proper JSON arrays.
  await db`
    UPDATE imported_gcal_events
    SET imported_by = (imported_by #>> '{}')::jsonb
    WHERE jsonb_typeof(imported_by) = 'string'
  `;

  // Device calendar events uploaded by members for cross-user visibility.
  // Each row represents one native device event from one user's device calendar,
  // shared into a specific SharedCal calendar.
  await db`
    CREATE TABLE IF NOT EXISTS imported_device_events (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      calendar_id     UUID NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
      user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      device_event_id TEXT NOT NULL,
      title           TEXT NOT NULL,
      start_time      TIMESTAMPTZ NOT NULL,
      end_time        TIMESTAMPTZ NOT NULL,
      description     TEXT,
      last_synced_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (calendar_id, user_id, device_event_id)
    )
  `;

  console.log("[db] migrations applied");
}
