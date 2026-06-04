<div align="center">
  <img src="frontend/assets/icons/app_icon.png" width="120" alt="Milo logo" />
  <h1>Milo — Shared Calendar</h1>
  <p><strong>Shared calendars, made simple.</strong></p>
  <a href="https://milocalendar.tech">🌐 milocalendar.tech</a>
</div>

---

## What is Milo?

Milo is a shared calendar app built for groups — families, friend circles, flatmates, or teams — who want one place to see what's happening and who's doing what.

Create a calendar, invite people with a code, and start adding events. Everyone stays in sync automatically via real-time updates. No accounts to manage for others, no complicated sharing settings — just a link and you're in.

## Vision

Most calendar apps are built around the individual. Milo is built around the group.

The goal is a calendar that feels as lightweight as a shared notes app but as powerful as a full scheduling tool — with polls to find the best time, event reminders so nothing slips through the cracks, and Google Calendar sync so Milo fits into whatever workflow you already have.

## Features

- **Shared calendars** — create or join via invite code, see everyone's events in one grid
- **Real-time sync** — events appear instantly for all members via WebSocket
- **Event polls** — propose multiple time options, let the group vote, confirm the winner
- **Recurring events** — daily, weekly, or monthly repeats with per-instance or series-wide editing
- **Reminders** — email and on-device notifications 30 minutes before an event starts
- **Google Calendar sync** — mirror events to your personal Google Calendar automatically
- **Emoji reactions** — react to events with any emoji; quick-pick the most common or open the full keyboard
- **Event icons** — attach an emoji icon to an event (20 presets or pick any emoji)
- **Profile editing** — change your display name, colour, and profile photo (Cloudinary-hosted avatar)
- **Sign in with Google** — or use email + password, your choice _(currently unavailable — see Known Limitations)_

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (iOS · Android · macOS) |
| Backend | Bun + TypeScript REST API + WebSocket |
| Database | PostgreSQL |
| Hosting | Render.com |
| CI/CD | GitLab CI |

## Getting started (local dev)

```bash
# Run the Flutter app
cd frontend && flutter run
```

See [CLAUDE.md](CLAUDE.md) for full setup, environment variables, and production deployment details.

> **Note:** The production backend runs on Render.com's free tier, which spins down after 15 minutes of inactivity. The first request after a cold start can take 30–60 seconds — subsequent requests are fast. If the app feels slow on first load, just give it a moment.

## Known Limitations

- **Google Sign In / Sign Up is not yet functional for the WebApp.** A native iOS OAuth client ID needs to be configured in the app before Google authentication works. Use email + password registration for now.
- Google Calendar sync (connecting your personal Google Calendar) is available and works independently of Google Sign-In.

---

<div align="center">
  <sub>Available at <a href="https://milocalendar.tech">milocalendar.tech</a></sub>
</div>
