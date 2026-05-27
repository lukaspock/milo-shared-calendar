# SharedCal

A shared calendar app — Flutter frontend + Bun/TypeScript REST API + WebSocket + PostgreSQL.

## Architecture

```
/
├── frontend/        Flutter mobile/desktop app (iOS, Android, macOS)
├── backend/         Bun + TypeScript REST API + WebSocket server
└── docker-compose.yml
```

## Running the stack locally

```bash
docker compose up --build
```

- Backend: `http://localhost:3000`
- Frontend: `flutter run` in `frontend/`

The `frontend` service is intentionally absent from docker-compose — Flutter runs natively.

## Production (Render.com)

Both the backend API and PostgreSQL database are hosted on Render.com.

| Service  | URL                                          |
|----------|----------------------------------------------|
| Backend  | `https://flutterprojectvibecoding.onrender.com` |
| DB (internal) | `postgresql://sharedcal_db_user:...@dpg-d85c41p9rddc73a7i9eg-a/sharedcal_db` |
| DB (external) | `postgresql://sharedcal_db_user:...@dpg-d85c41p9rddc73a7i9eg-a.oregon-postgres.render.com/sharedcal_db` |

The internal DB hostname only works from within Render. Use the external hostname for local psql access or `backend/.env`.

**Render Free Tier caveat:** The backend sleeps after 15 min of inactivity. First request after sleep takes 30–60 s. This is the main cause of perceived slowness on physical devices.

## Running on a physical device

```bash
# macOS desktop (default: 127.0.0.1)
flutter run -d macos

# Release build (much faster than debug)
flutter run --release

# Android / iPhone on local network
ipconfig getifaddr en0
flutter run --dart-define=API_HOST=<your-mac-ip>

# Against production backend
flutter run --dart-define=API_HOST=flutterprojectvibecoding.onrender.com
```

Phone and Mac must be on the same network for local dev. Check macOS Firewall if the phone can't connect (System Settings → Network → Firewall).

## Environment

Backend config is in `backend/.env` for local dev and overridden by `docker-compose.yml` for containers.

| Variable         | Local value                                          | docker-compose value                             |
|------------------|------------------------------------------------------|--------------------------------------------------|
| `DATABASE_URL`   | Render external postgres URL                         | `postgres://postgres:postgres@db:5432/sharedcal` |
| `JWT_SECRET`     | `change_me_in_production`                            | `change_me_in_production`                        |
| `PORT`           | `3000`                                               | `3000`                                           |
| `RESEND_API_KEY` | your Resend API key                                  | `your_resend_api_key_here` (placeholder)         |
| `APP_URL`        | `http://localhost:3000`                              | `http://localhost:3000`                          |
| `FROM_EMAIL`     | omit — defaults to `onboarding@resend.dev`           | omit                                             |

Keep `JWT_SECRET` identical between `.env` and docker-compose — a mismatch causes silent 401s.

**Resend email:** Without a verified domain, `FROM_EMAIL` must be omitted or set to `onboarding@resend.dev`. Setting it to a Gmail or unverified domain causes a 403 from Resend. The `RESEND_API_KEY` in `docker-compose.yml` is a placeholder — set the real key only in `backend/.env` (never commit it).

## Resetting the database

Schema changes require a volume reset since Postgres only runs init scripts on first start:

```bash
docker compose down -v
docker compose up --build
```

Required after adding the poll tables (`event_polls`, `poll_options`, `poll_votes`).
The production Render DB was migrated manually via psql — those tables already exist there.

`backend/src/db/migrate.ts` runs automatically on every backend start via `runMigrations()` in `index.ts`. It uses `ADD COLUMN IF NOT EXISTS` so it's safe to run repeatedly. Currently adds `email_verified`, `verification_token`, `verification_expires_at` to `users`.

## Database schema (summary)

| Table                    | Purpose                                                                          |
|--------------------------|----------------------------------------------------------------------------------|
| `users`                  | Accounts — email, password_hash (nullable), name, color, google_id               |
| `calendars`              | Calendars — name, owner_id, invite_code                                          |
| `calendar_members`       | Junction — user_id, calendar_id, role (owner/member)                             |
| `events`                 | Calendar events — title, start_time, end_time, color                             |
| `event_polls`            | Polls — title, options, open/closed state                                        |
| `poll_options`           | Time-slot options for a poll                                                     |
| `poll_votes`             | Per-user votes (yes/no/maybe) per option                                         |
| `google_calendar_tokens` | Per-user Google OAuth tokens for Calendar sync                                   |
| `google_event_ids`       | Mapping SharedCal event IDs → Google Calendar event IDs per user                 |

## Features

- **Auth:** Register / login with JWT (email+password) OR Sign in with Google. Token stored in SharedPreferences.
- **Email verification:** Verification email sent on register via Gmail API. Banner in app with auto-poll (every 5 s) — disappears automatically once verified. "Resend email" button available.
- **Calendars:** Create, join via invite code, view members, kick members (owner only). Owner can delete calendar (cascades all data), members can leave.
- **Account deletion:** Users can delete their own account from the home screen.
- **Events:** Create / edit / delete events. Multi-day events appear on every spanned day in the calendar grid. Real-time sync via PostgreSQL NOTIFY → WebSocket. Email notification sent to all verified members (except creator) on new event.
- **Event Polls:** Propose an event with multiple time options. Members vote yes/no/maybe per option. Creator confirms a winning option → automatically creates a regular event + email notification to all verified members.
- **Real-time:** WebSocket broadcasts `event_created`, `event_updated`, `event_deleted`, `poll_update`, `member_joined`, `member_notification`.
- **Google Calendar sync** _(Google-signed-in users only)_: Events are mirrored to the user's personal Google Calendar automatically.

## Google Sign-In & Calendar integration

Users can authenticate via email+password or via Google Sign-In:

| Auth method | Google Calendar sync |
|-------------|---------------------|
| Email + password | ❌ Not available |
| Sign in with Google | ✅ Automatic |

**Flow:**
1. User taps "Sign in with Google" in the Flutter app
2. `google_sign_in` package shows the native Google consent screen (requests Calendar scope)
3. Flutter sends the Google ID token + server auth code to `POST /auth/google`
4. Backend verifies the ID token, creates or finds the user, stores refresh token in `google_calendar_tokens`
5. Returns a SharedCal JWT — app behaves identically from here
6. Events created/updated/deleted call Google Calendar API in the background (fire-and-forget)

**Google Cloud Project:** `SharedCal` — same project used for Gmail email sending.
Enabled APIs: Gmail API, Google Calendar API v3.
OAuth client: Web application type (Client ID `583283682704-...`).

## Known gotchas

- PostgreSQL `COUNT(*)` returns `bigint` — cast to `::integer` in all queries or `JSON.stringify` will throw.
- `JWT_SECRET` mismatch between `.env` and docker-compose causes silent 401s. Symptom: "Could not load calendars" immediately after login — clear app data and re-login.
- Render Free Tier cold starts take 30–60 s. Always test performance with `flutter run --release`.
- `.claude/worktrees/` is in `.gitignore` — these are temporary Claude Code working directories.
- The Render internal DB hostname (`dpg-...`) only resolves from within Render's network.
- Resend 403 "domain not verified": happens when `FROM_EMAIL` is set to a Gmail or unverified domain. Remove `FROM_EMAIL` to fall back to `onboarding@resend.dev`.
- After schema changes locally: `docker compose down -v && docker compose up --build` (migrations auto-run but new tables in `schema.sql` need a volume reset).
