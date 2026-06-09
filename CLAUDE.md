# Milo

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
| Backend  | `https://api.milocalendar.tech` |
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
flutter run --dart-define=API_HOST=api.milocalendar.tech
```

Phone and Mac must be on the same network for local dev. Check macOS Firewall if the phone can't connect (System Settings → Network → Firewall).

## Environment

Backend config is in `backend/.env` for local dev and overridden by `docker-compose.yml` for containers.

| Variable                | Local value                                          | docker-compose value                             |
|-------------------------|------------------------------------------------------|--------------------------------------------------|
| `DATABASE_URL`          | Render external postgres URL                         | `postgres://postgres:postgres@db:5432/sharedcal` |
| `JWT_SECRET`            | `change_me_in_production`                            | `change_me_in_production`                        |
| `PORT`                  | `3000`                                               | `3000`                                           |
| `APP_URL`               | `http://localhost:3000`                              | `http://localhost:3000`                          |
| `GOOGLE_CLIENT_ID`      | Web OAuth client ID from Google Cloud Console        | same                                             |
| `GOOGLE_CLIENT_SECRET`  | Web OAuth client secret                              | same                                             |
| `GOOGLE_REFRESH_TOKEN`  | Refresh token for the Gmail sending account          | same                                             |
| `GOOGLE_IOS_CLIENT_ID`  | iOS OAuth client ID (for verifying iOS ID tokens)    | same                                             |
| `FROM_EMAIL`            | omit — defaults to `lukaspock.dev@gmail.com`         | omit                                             |
| `ENCRYPTION_KEY`        | Exactly 32 ASCII chars — encrypts Google tokens in DB | `local-dev-encryption-key-32ch` (via `$ENCRYPTION_KEY` fallback) |

Keep `JWT_SECRET` identical between `.env` and docker-compose — a mismatch causes silent 401s.

## Resetting the database

Schema changes require a volume reset since Postgres only runs init scripts on first start:

```bash
docker compose down -v
docker compose up --build
```

Required after adding the poll tables (`event_polls`, `poll_options`, `poll_votes`).
The production Render DB was migrated manually via psql — those tables already exist there.

`backend/src/db/migrate.ts` runs automatically on every backend start via `runMigrations()` in `index.ts`. It uses `ADD COLUMN IF NOT EXISTS` so it's safe to run repeatedly. Adds all schema changes since the initial `schema.sql` — see the file for the full list.

## Database schema (summary)

| Table                      | Purpose                                                                                    |
|----------------------------|--------------------------------------------------------------------------------------------|
| `users`                    | Accounts — email, password_hash (nullable), name, color, avatar_url, google_id            |
| `calendars`                | Calendars — name, owner_id, invite_code                                                    |
| `calendar_members`         | Junction — user_id, calendar_id, role (owner/member)                                       |
| `events`                   | Calendar events — title, start_time, end_time, color, icon, recurrence fields              |
| `event_reactions`          | Emoji reactions — event_id, user_id, emoji (PK on all three)                               |
| `event_polls`              | Polls — title, options, open/closed state                                                   |
| `poll_options`             | Time-slot options for a poll                                                                |
| `poll_votes`               | Per-user votes (yes/no/maybe) per option                                                    |
| `google_calendar_tokens`   | Per-user Google OAuth tokens for Calendar sync                                              |
| `google_event_ids`         | Mapping Milo event IDs → Google Calendar event IDs per user                                |
| `imported_gcal_events`     | Cached events imported from members' Google Calendars (keyed by calendar_id + ical_uid)    |
| `imported_device_events`   | Device calendar events uploaded by members (keyed by calendar_id + user_id + device_event_id) |
| `pending_calendar_connects`| Short-lived OAuth state tokens for Google Calendar connect flow (15 min TTL)               |
| `event_photos`             | Photo memories attached to events — Cloudinary URLs, per calendar                          |

## Features

- **Auth:** Register / login with JWT (email+password). Password reset via email link (`POST /auth/forgot-password`, `GET/POST /auth/reset-password/:token`). Google Sign-In is implemented in code but currently non-functional (iOS native OAuth client ID not configured — see Known issues). Token stored in SharedPreferences.
- **Email verification:** Verification email sent on register via Gmail API. Banner in app with auto-poll (every 5 s) — disappears automatically once verified. "Resend email" button available.
- **Calendars:** Create, join via invite code, view members, kick members (owner only). Members sheet shows each member's profile photo (falls back to colour initial). Owner can delete calendar (cascades all data), members can leave. On join, the joining user's Google Calendar and Device Calendar events are imported immediately (no need to open the calendar screen first). When an owner deletes the calendar, all other members instantly receive a `calendar_deleted` WS broadcast and are navigated back to `/home` with a snackbar notification.
- **Account deletion:** Users can delete their own account from the home screen.
- **Events:** Create / edit / delete events. Optional icon per event — 20 preset emojis, any emoji via full keyboard, or a custom photo (uploaded to Cloudinary `event_icons/`). The icon is shown in the calendar grid day cell and in the event row (left box) instead of the date. Multi-day events appear on every spanned day in the calendar grid. Real-time sync via PostgreSQL NOTIFY → WebSocket. Email notification sent to all verified members (except creator) on new event.
- **Recurring events:** Daily, weekly, or monthly recurrence. Each instance is stored as a DB row with `parent_event_id`. Editing supports single-instance or all-future-instances modes.
- **Custom reminders:** On-device notification with configurable lead time (None / 5 min / 15 min / 30 min / 1 h / 2 h / 1 day) per event, selected via a chip row in `EventDetailScreen`. Preference is persisted per event in `SharedPreferences` so the edit form pre-fills the previously chosen value. Same chip picker appears in the poll-confirm dialog in `PollDetailScreen`.
- **Emoji reactions:** React to any event with any emoji. Quick-pick 8 common emojis or open the full emoji keyboard. One row per user+emoji+event. Broadcast in real-time via WebSocket `reaction_update`.
- **Profile editing:** `PATCH /auth/me` — update name, colour, and avatar URL. Profile photos upload directly from device to Cloudinary (unsigned preset, cloud `dvlvgosxk`, folder `avatars`) and are stored as a CDN URL on the user record.
- **Event Polls:** Propose an event with multiple time options. Members vote yes/no/maybe per option. Creator confirms a winning option → automatically creates a regular event + email notification to all verified members.
- **Photo memories:** Attach photos to events. Photos upload to Cloudinary (`event_photos/` folder) and are stored per calendar. Scrollable photo grid with real-time sync via WebSocket.
- **Real-time:** WebSocket broadcasts `event_created`, `event_updated`, `event_deleted`, `poll_update`, `member_joined`, `member_notification`, `reaction_update`, `gcal_synced`, `device_synced`, `calendar_deleted`.
- **Google Calendar sync (bidirectional):**
  - *Milo → Google*: Events created/updated/deleted in Milo are mirrored to each connected member's personal Google Calendar (fire-and-forget, tagged with `sharedcal_origin: true` to avoid re-import).
  - *Google → Milo*: Events from connected members' Google Calendars are imported into `imported_gcal_events` and shown read-only with "contributed by" attribution. Cache refreshes every 5 min via `startGoogleCalendarSyncScheduler` (backend background job) and on every `GET /calendars/:id/events` when stale. Broadcasts `gcal_synced` when done.
  - Connect/disconnect via in-app banner → `POST /auth/google-calendar/connect` / `DELETE /auth/google-calendar/disconnect`.
- **Device Calendar sharing:** Members can share their iOS/Android device calendar events with the group via `POST /calendars/:id/device-events`. Events are stored in `imported_device_events` and shown to all members. The frontend reads device events every 5 minutes (`Timer.periodic`) and uploads only when the set of event IDs changes. Broadcasts `device_synced` on change.

## Google Sign-In & Calendar integration

> **⚠️ Google Sign In / Sign Up is currently non-functional.** The `google_sign_in` package is integrated and the backend endpoint (`POST /auth/google`) is implemented, but the iOS native OAuth client has not been set up. `ios/Runner/Info.plist` still contains the placeholder `REPLACE_WITH_REVERSED_CLIENT_ID`. To fix: create an iOS OAuth client in Google Cloud Console (bundle ID `com.sharedcal.sharedCal`) and replace the placeholder with the reversed client ID. Google Calendar sync (web OAuth flow) is unaffected and works fine.

Users can authenticate via email+password. Once working, Google Sign-In will also be available. Either way, users can connect Google Calendar:

| Auth method | Google Calendar sync |
|-------------|---------------------|
| Email + password | ✅ Via "Connect Google Calendar" banner in app |
| Sign in with Google | ⚠️ Not yet functional (see above) |

**Google Sign-In flow (once configured):**
1. User taps "Sign in with Google" in the Flutter app
2. `google_sign_in` package shows the native Google consent screen
3. Flutter sends the Google ID token to `POST /auth/google`
4. Backend verifies the ID token, creates or finds the user
5. Returns a Milo JWT — app behaves identically from here

**Web OAuth connect flow (all users):**
1. User taps "Connect Google Calendar" banner in the app
2. App calls `POST /auth/google-calendar/connect` → gets an OAuth URL with `access_type=offline&prompt=consent`
3. App opens the URL in the device browser via `url_launcher`
4. User grants Calendar access — Google redirects to `GET /auth/google-calendar/callback`
5. Backend validates state, exchanges code for tokens, stores in `google_calendar_tokens`
6. App returns to foreground → `WidgetsBindingObserver` triggers `refreshUser()` → banner auto-dismisses
7. All future events created/updated/deleted are mirrored to Google Calendar (fire-and-forget)

**Google Cloud Project:** `SharedCal` — same project used for Gmail email sending.
Enabled APIs: Gmail API, Google Calendar API v3.
OAuth client: Web application type (Client ID `583283682704-...`).
Callback URL must be registered: `https://api.milocalendar.tech/auth/google-calendar/callback`.

## Known issues

- **Google Sign In / Sign Up does not work.** The iOS OAuth client ID in `ios/Runner/Info.plist` is still the placeholder `REPLACE_WITH_REVERSED_CLIENT_ID`. Create a native iOS OAuth client in Google Cloud Console and replace it before Google authentication will function. Google Calendar sync is unaffected.

## Known gotchas

- PostgreSQL `COUNT(*)` returns `bigint` — cast to `::integer` in all queries or `JSON.stringify` will throw.
- `JWT_SECRET` mismatch between `.env` and docker-compose causes silent 401s. Symptom: "Could not load calendars" immediately after login — clear app data and re-login.
- Render Free Tier cold starts take 30–60 s. Always test performance with `flutter run --release`.
- `.claude/worktrees/` is in `.gitignore` — these are temporary Claude Code working directories.
- The Render internal DB hostname (`dpg-...`) only resolves from within Render's network.
- **`ENCRYPTION_KEY` must be set on Render** (exactly 32 ASCII chars). If missing, `encrypt()` throws inside `handleCalendarCallback`, which is swallowed by the catch and returns `false` → users see "Invalid or expired session" on Google Calendar connect. Set it once in the Render dashboard under Environment Variables.
- Google Calendar connect requires `APP_URL` to be set correctly on the backend — the OAuth callback redirects to `$APP_URL/auth/google-calendar/callback`. Locally this won't work unless you expose the backend via a tunnel.
- After schema changes locally: `docker compose down -v && docker compose up --build` (migrations auto-run but new tables in `schema.sql` need a volume reset).
- Cloudinary uploads use an **unsigned** preset (`avatars`, cloud `dvlvgosxk`) — the cloud name and preset name are safe to commit. The API secret is never used or stored in the app. Avatar photos go to the `avatars/` folder; event icon photos go to `event_icons/`, and photo memories go to `event_photos/`. All use the same preset.
- **`startGoogleCalendarSyncScheduler`** fires every 5 min in the backend. It runs `fetchAndCacheGoogleEventsForCalendar` for every calendar that has at least one gcal-connected member. A running-flag prevents overlapping runs. On Render Free Tier the process sleeps after inactivity — the scheduler resumes on the next wake-up.
- **Device Calendar periodic sync** runs as a `Timer.periodic` (5 min) inside each `EventsNotifier`. It only uploads when the set of device event IDs changes. The timer is cancelled in `dispose()`, so it stops when the user leaves the calendar screen.
- **Imported events are never written back** to other members' Google/Device Calendars — `syncEvent` is only called for native Milo events (`event_created` WS), never for `source: google_import` or `source: device_import` events.
