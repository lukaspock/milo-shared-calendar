# SharedCal

A shared calendar app with a Flutter frontend and a Bun/TypeScript backend backed by PostgreSQL.

## Architecture

```
/
├── frontend/   Flutter mobile/desktop app
├── backend/    Bun + TypeScript REST API + WebSocket server
└── docker-compose.yml
```

## Running the stack

```bash
docker compose up --build
```

- Backend: `http://localhost:3000`
- Frontend: run via `flutter run` in `frontend/`

The `frontend` service was intentionally removed from docker-compose — Flutter runs natively, not in Docker.

## Running on a physical device

The Flutter app uses `--dart-define=API_HOST` to set the backend URL at build time:

```bash
# macOS desktop (default: 127.0.0.1)
flutter run -d macos

# Android / iPhone (use Mac's local network IP)
ipconfig getifaddr en0
flutter run --dart-define=API_HOST=<your-mac-ip>
```

Phone and Mac must be on the same network. If the phone can't reach the backend, check macOS Firewall (System Settings → Network → Firewall).

## Environment

Backend config lives in `backend/.env` for local dev and is overridden by `docker-compose.yml` for containers. Keep `JWT_SECRET` in sync between both — a mismatch causes 401 errors for existing sessions.

| Variable       | docker-compose value                             |
|----------------|--------------------------------------------------|
| `DATABASE_URL` | `postgres://postgres:postgres@db:5432/sharedcal` |
| `JWT_SECRET`   | `change_me_in_production`                        |
| `PORT`         | `3000`                                           |

## Resetting the database

Schema changes require a volume reset since Postgres only runs init scripts on first start:

```bash
docker compose down -v
docker compose up --build
```

## Known gotchas

- PostgreSQL `COUNT(*)` returns `bigint` — cast to `::integer` in all queries or `JSON.stringify` will throw.
- `JWT_SECRET` mismatch between `.env` and docker-compose causes silent 401s. If the app shows "Could not load calendars" instantly after login, this is the likely cause — clear app data and re-login.
- `.claude/worktrees/` should be in `.gitignore` — these are temporary Claude Code working directories.
