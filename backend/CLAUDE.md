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
├── index.ts               Entry point — registers all routes, runs migrations, starts WS + NOTIFY listener
├── src/
│   ├── router.ts          Minimal regex-based router (Router class, json(), error() helpers)
│   ├── types.ts           RequestContext, JwtPayload types
│   ├── db/
│   │   ├── client.ts      Bun.sql singleton — import as `db`
│   │   ├── migrate.ts     Idempotent migrations — runs on every start
│   │   └── schema.sql     Full DB schema (run once on first Postgres start)
│   ├── middleware/
│   │   └── auth.middleware.ts  JWT verification → attaches ctx.user
│   ├── routes/
│   │   ├── auth.ts        Register, login, verify email, resend verification, GET /auth/me
│   │   ├── calendars.ts   Calendar CRUD + member management + delete + leave
│   │   ├── events.ts      Event CRUD + notify endpoint + email notifications
│   │   └── polls.ts       Poll CRUD + vote + confirm + email notifications
│   ├── services/
│   │   └── email.ts       Resend API wrapper — verification + event + poll emails
│   └── ws/
│       └── websocket.ts   WS handler + room management + Postgres NOTIFY listener
```

## API routes

### Auth
| Method | Path                          | Auth | Description                                      |
|--------|-------------------------------|------|--------------------------------------------------|
| POST   | `/auth/register`              | —    | Create account, sends verification email         |
| POST   | `/auth/login`                 | —    | Get JWT token, returns `email_verified`          |
| GET    | `/auth/verify/:token`         | —    | Verify email via link — returns HTML page        |
| POST   | `/auth/resend-verification`   | JWT  | Regenerate + resend verification email           |
| GET    | `/auth/me`                    | JWT  | Return current user (fresh from DB)              |

### Users (require JWT)
| Method | Path         | Description              |
|--------|--------------|--------------------------|
| DELETE | `/users/me`  | Delete own account       |

### Calendars (all require JWT)
| Method | Path                                | Description                      |
|--------|-------------------------------------|----------------------------------|
| GET    | `/calendars`                        | List user's calendars            |
| POST   | `/calendars`                        | Create calendar                  |
| POST   | `/calendars/join`                   | Join via invite code             |
| DELETE | `/calendars/:id`                    | Delete calendar (owner only, cascades all data) |
| POST   | `/calendars/:id/leave`              | Leave calendar (non-owners only) |
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

## Email service

`src/services/email.ts` wraps the Resend REST API via `fetch()`. No SDK dependency.

- Graceful no-op when `RESEND_API_KEY` is not set (logs skip message).
- `FROM` defaults to `onboarding@resend.dev` — do not set `FROM_EMAIL` to a Gmail or unverified domain (Resend returns 403).
- All email sends in routes are fire-and-forget IIFEs: `(async () => { ... })().catch(console.error)` — they never block the HTTP response.
- Email notifications (event created, poll confirmed) only go to members with `email_verified = true`.

| Function                       | Trigger                        |
|--------------------------------|--------------------------------|
| `sendVerificationEmail`        | Register + resend-verification |
| `sendEventNotification`        | New event created              |
| `sendPollConfirmedNotification`| Poll confirmed as event        |

## Known gotchas

- `Bun.sql` template tags are not `postgres.js` — array parameters work differently. Use `JOIN` queries instead of `WHERE id = ANY(${array})` to avoid driver issues.
- The PostgreSQL NOTIFY listener uses a separate `postgres.js` connection (imported dynamically in `startNotifyListener`) because `Bun.sql` doesn't support `LISTEN` yet.
- `tsconfig.json` has `strict: true` — all map/filter callbacks over `db` results need explicit `: Record<string, unknown>` or `any` types.
- `migrate.ts` runs `ADD COLUMN IF NOT EXISTS` — safe to run on every start, never drops data.
