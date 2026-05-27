# SharedCal Backend

Bun + TypeScript REST API with WebSocket support, backed by PostgreSQL.

## Stack

- **Runtime:** Bun (not Node.js — use `bun`, `bunx`, `bun test`)
- **Database:** `Bun.sql` (built-in Postgres client, no `pg` or `postgres.js`)
- **WebSocket:** Built-in via `Bun.serve()` (no `ws` package)
- **Auth:** JWT (`jsonwebtoken` package), bcrypt for passwords
- **Config:** `.env` auto-loaded by Bun — no `dotenv` needed

## Project layout

```
backend/
├── index.ts               Entry point — registers all routes, starts WS + NOTIFY listener
├── src/
│   ├── router.ts          Minimal regex-based router (Router class, json(), error() helpers)
│   ├── types.ts           RequestContext, JwtPayload types
│   ├── db/
│   │   ├── client.ts      Bun.sql singleton — import as `db`
│   │   └── schema.sql     Full DB schema (run once on first Postgres start)
│   ├── middleware/
│   │   └── auth.middleware.ts  JWT verification → attaches ctx.user
│   ├── routes/
│   │   ├── auth.ts        POST /auth/register, POST /auth/login
│   │   ├── calendars.ts   Calendar CRUD + member management
│   │   ├── events.ts      Event CRUD + notify endpoint
│   │   └── polls.ts       Poll CRUD + vote + confirm
│   └── ws/
│       └── websocket.ts   WS handler + room management + Postgres NOTIFY listener
```

## API routes

### Auth
| Method | Path                       | Description                                        |
|--------|----------------------------|----------------------------------------------------|
| POST   | `/auth/register`           | Create account (email+password)                    |
| POST   | `/auth/login`              | Get JWT token (email+password)                     |
| POST   | `/auth/google`             | Sign in / register via Google ID token             |
| GET    | `/auth/verify/:token`      | Verify email address (browser link)                |
| POST   | `/auth/resend-verification`| Resend verification email                          |
| GET    | `/auth/me`                 | Get current user info                              |
| DELETE | `/auth/me`                 | Delete account                                     |

### Calendars (all require JWT)
| Method | Path                                | Description                      |
|--------|-------------------------------------|----------------------------------|
| GET    | `/calendars`                        | List user's calendars            |
| POST   | `/calendars`                        | Create calendar                  |
| POST   | `/calendars/join`                   | Join via invite code             |
| GET    | `/calendars/:id/events`             | List events (with creator info)  |
| GET    | `/calendars/:id/members`            | List members                     |
| DELETE | `/calendars/:id/members/:userId`    | Kick member (owner only)         |

### Events (all require JWT)
| Method | Path                 | Description                        |
|--------|----------------------|------------------------------------|
| POST   | `/events`            | Create event                       |
| PUT    | `/events/:id`        | Update event (any member)          |
| DELETE | `/events/:id`        | Delete event (creator or owner)    |
| POST   | `/events/:id/notify` | Push WS notification to members   |

### Polls (all require JWT)
| Method | Path                            | Description                                          |
|--------|---------------------------------|------------------------------------------------------|
| POST   | `/calendars/:calendarId/polls`  | Create poll with time options                        |
| GET    | `/calendars/:calendarId/polls`  | List all polls (open + closed)                       |
| GET    | `/polls/:id`                    | Get single poll with options + votes                 |
| POST   | `/polls/:id/vote`               | Vote yes/no/maybe on an option (upsert)              |
| POST   | `/polls/:id/confirm`            | Creator confirms winning option → creates event      |
| DELETE | `/polls/:id`                    | Delete poll (creator or calendar owner)              |

## WebSocket protocol

Connect to `/ws`. Messages are JSON.

**Client → Server:**
```json
{ "type": "auth", "token": "<jwt>" }
{ "type": "subscribe", "calendarIds": ["uuid", ...] }
```

**Server → Client:**
```json
{ "type": "auth_ok", "userId": "..." }
{ "type": "subscribed", "calendarIds": [...] }
{ "type": "event_created", "event": { ... } }
{ "type": "event_updated", "event": { ... } }
{ "type": "event_deleted", "event_id": "...", "calendar_id": "..." }
{ "type": "poll_update", "poll_id": "...", "calendar_id": "..." }
{ "type": "member_joined", "calendar_id": "...", "member_count": 3 }
{ "type": "member_notification", "event_id": "...", "sender_name": "...", "message": "..." }
```

Events are also broadcast via PostgreSQL NOTIFY on channel `calendar_events` for cross-process sync.

## Database patterns

Use the `db` tagged template literal for all queries:

```ts
import db from "../db/client";

// Single row
const rows = await db`SELECT * FROM users WHERE id = ${userId}`;
const user = rows[0]; // undefined if not found

// Insert returning
const result = await db`INSERT INTO ... RETURNING *`;

// COUNT must be cast — PostgreSQL returns bigint
const count = await db`SELECT COUNT(*)::integer AS n FROM ...`;

// Upsert
await db`
  INSERT INTO poll_votes (option_id, user_id, vote)
  VALUES (${optionId}, ${userId}, ${vote})
  ON CONFLICT (option_id, user_id) DO UPDATE SET vote = ${vote}, voted_at = now()
`;
```

**Never use `COUNT(*)` without `::integer` cast** — `JSON.stringify` will silently drop bigint values.

## Auth middleware

```ts
import { authMiddleware } from "./middleware/auth.middleware";

router.get("/protected", handler, [authMiddleware]);
// ctx.user!.sub = userId (UUID string)
```

## Running locally

```bash
bun install
bun run index.ts      # or: bun --hot index.ts for hot reload
```

Requires `DATABASE_URL` in `backend/.env`. See root `CLAUDE.md` for the Render connection strings.

## Google Calendar integration (backend)

Users who signed in via Google have a row in `google_calendar_tokens`. All event mutations (create/update/delete) call `syncToGoogleCalendar(userId, ...)` from `src/services/google_calendar.ts` — fire-and-forget, errors are logged but never block the response.

`google_calendar_tokens` schema:
```sql
CREATE TABLE google_calendar_tokens (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  access_token TEXT,
  refresh_token TEXT NOT NULL,
  expiry TIMESTAMPTZ,
  google_calendar_id TEXT DEFAULT 'primary'
);
```

`POST /auth/google` body: `{ idToken: string, serverAuthCode: string }`. The ID token identifies the user; the server auth code is exchanged for refresh+access tokens.

## Known gotchas

- `Bun.sql` template tags are not `postgres.js` — array parameters work differently. Use `JOIN` queries instead of `WHERE id = ANY(${array})` to avoid driver issues.
- The PostgreSQL NOTIFY listener uses a separate `postgres.js` connection (imported dynamically in `startNotifyListener`) because `Bun.sql` doesn't support `LISTEN` yet.
- `tsconfig.json` has `strict: true` — all map/filter callbacks over `db` results need explicit `: Record<string, unknown>` or `any` types.
