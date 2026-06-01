# SharedCal Backend

Bun + TypeScript REST API with WebSocket support, backed by PostgreSQL.

## Stack

- **Runtime:** Bun
- **Database:** `Bun.sql` (built-in Postgres client)
- **WebSocket:** Built-in `Bun.serve()`
- **Auth:** JWT + bcrypt
- **Email:** Gmail REST API via `googleapis`

## Running locally

```bash
bun install
bun run index.ts        # standard
bun --hot index.ts      # hot reload
```

Requires a `backend/.env` file. Copy the template and fill in values:

```bash
DATABASE_URL=postgresql://...
JWT_SECRET=change_me_in_production
PORT=3000
APP_URL=http://localhost:3000
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REFRESH_TOKEN=...
GOOGLE_IOS_CLIENT_ID=...
```

Or use the full stack with Docker:

```bash
# from repo root
docker compose up --build
```

See the root [CLAUDE.md](../CLAUDE.md) for full environment variable reference and production details.

## API overview

| Group | Base path | Description |
|-------|-----------|-------------|
| Auth | `/auth` | Register, login, Google OAuth, email verification |
| Calendars | `/calendars` | Create, join, manage members |
| Events | `/events` | CRUD + real-time WS notifications |
| Polls | `/calendars/:id/polls` | Create, vote, confirm |

See [CLAUDE.md](CLAUDE.md) for the full route table and WebSocket protocol.

## Known issues

- **Google Sign In / Sign Up is not yet functional** on the client side (iOS OAuth client ID not configured). The backend endpoint `POST /auth/google` is fully implemented and ready.
