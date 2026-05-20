# SharedCal Frontend

Flutter app targeting iOS, Android, and macOS. State management via Riverpod, navigation via go_router, HTTP via Dio, real-time via WebSocket.

## Key dependencies

| Package               | Purpose                                           |
|-----------------------|---------------------------------------------------|
| `flutter_riverpod`    | State management (StateNotifierProvider)          |
| `go_router`           | Declarative routing                               |
| `dio`                 | HTTP client — JWT Bearer token injected globally  |
| `web_socket_channel`  | WebSocket for real-time updates                   |
| `shared_preferences`  | Persist JWT token + user data across restarts     |
| `google_fonts`        | Plus Jakarta Sans used throughout                 |
| `intl`                | Date formatting                                   |

## Project layout

```
lib/
├── main.dart                   Entry point — loads saved hue prefs, runs app
├── app.dart                    GoRouter config + MaterialApp.router
├── theme/
│   └── app_theme.dart          Design tokens, CalHue palette, StickerTile widget, hueFor()
├── models/
│   ├── calendar.dart           CalendarModel
│   ├── event.dart              CalendarEvent
│   ├── member.dart             CalendarMember
│   ├── poll.dart               EventPoll, PollOption, PollVote, PollOptionInput
│   └── user.dart               AppUser
├── services/
│   ├── api_service.dart        Dio singleton — all HTTP calls, Bearer token interceptor
│   ├── auth_service.dart       Login/register/logout + SharedPreferences session
│   └── websocket_service.dart  Singleton WS — auth + subscribe + reconnect logic
├── providers/
│   ├── auth_provider.dart      AuthNotifier (loading → authenticated/unauthenticated)
│   ├── calendar_provider.dart  CalendarNotifier — re-created on auth status change
│   ├── events_provider.dart    EventsNotifier per calendarId (family provider)
│   └── polls_provider.dart     PollsNotifier per calendarId (family provider)
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart        Calendar list, create/join calendar
│   ├── calendar_screen.dart    Monthly grid + day events + open polls list
│   ├── event_detail_screen.dart  Create / edit event
│   ├── create_poll_screen.dart   Create poll with multiple time options
│   └── poll_detail_screen.dart   View poll, vote yes/no/maybe, creator confirms
└── widgets/
    ├── app_button.dart
    ├── app_text_field.dart
    └── members_dialog.dart
```

## Routing

| Path                                    | Screen                |
|-----------------------------------------|-----------------------|
| `/`                                     | SplashScreen          |
| `/login`                                | LoginScreen           |
| `/register`                             | RegisterScreen        |
| `/home`                                 | HomeScreen            |
| `/calendar/:calendarId`                 | CalendarScreen        |
| `/calendar/:calendarId/event/:eventId`  | EventDetailScreen     |
| `/calendar/:calendarId/polls/new`       | CreatePollScreen      |
| `/calendar/:calendarId/polls/:pollId`   | PollDetailScreen      |

Navigation: always use `context.go(...)`. Pass objects via `extra:` for instant display before API data loads.

## Backend URL

Configured at build time via `--dart-define=API_HOST`. Defaults to `flutterprojectvibecoding.onrender.com` (production).

```bash
# Production (default)
flutter run

# Release build — always test performance this way, debug is 5-10× slower
flutter run --release

# Local backend
flutter run --dart-define=API_HOST=127.0.0.1

# Physical device against local backend
flutter run --dart-define=API_HOST=<mac-local-ip>
```

Defined in `api_service.dart` and `websocket_service.dart`. HTTP uses `https://` for remote, `http://` for local. WS uses `wss://` for remote, `ws://` for local.

## State management

All providers are `StateNotifierProvider`. Family providers take `calendarId: String`.

```dart
// Watch (rebuilds widget on change)
final events = ref.watch(eventsProvider(calendarId)).valueOrNull ?? [];

// Read (one-shot, in callbacks)
await ref.read(eventsProvider(calendarId).notifier).createEvent(...);
```

- `authProvider` — global auth state. `calendarProvider` watches it and re-fetches on login/logout.
- `eventsProvider(calendarId)` — subscribes to WS on init, handles `event_created/updated/deleted`.
- `pollsProvider(calendarId)` — subscribes to WS on init, refreshes on `poll_update`.
- `ApiService` and `WebSocketService` are singletons (factory constructors).

## WebSocket flow

1. `WebSocketService.subscribeToCalendar(id)` connects on first call, sends `auth` message.
2. On `auth_ok`, sends `subscribe` for all accumulated calendar IDs.
3. All providers register a listener via `_ws.addListener(cb)` and remove it in `dispose()`.
4. On disconnect, auto-reconnects after 3 s.

## Design system

All colors in `AppTheme` (`theme/app_theme.dart`). Never hardcode hex values.

| Token                | Hex       | Usage                    |
|----------------------|-----------|--------------------------|
| `AppTheme.bg`        | `#FFF8F0` | Scaffold background      |
| `AppTheme.surface`   | `#FFFFFF` | Cards, bottom sheets     |
| `AppTheme.surfaceSoft`| `#FBF1E4`| Subtle backgrounds       |
| `AppTheme.line`      | `#EFE4D2` | Borders, dividers        |
| `AppTheme.ink`       | `#1F1B16` | Primary text, icons      |
| `AppTheme.inkSoft`   | `#6B6357` | Secondary text           |
| `AppTheme.inkMuted`  | `#A39A8C` | Placeholder, labels      |
| `AppTheme.danger`    | `#E85535` | Destructive actions      |

**Cards:** `BorderRadius.circular(18-24)`, `Border.all(color: AppTheme.line, width: 1.5)`, `BoxShadow(offset: Offset(0,4), blurRadius: 0)`.

**Hues:** Each calendar gets a `CalHue` from `stickerHues` (8 pastel options). Use `hueFor(calendar)` to resolve. Use `persistCalendarHue(id, index)` to save the user's choice.

**Font:** `GoogleFonts.plusJakartaSans(...)` for all text. Weights: w500 body, w600 labels, w700 titles, w800 section headers.

**Vote chips (polls):**
- yes → `Color(0xFFD4EDDA)` bg, `Color(0xFF28A745)` border
- maybe → `Color(0xFFFFF3CD)` bg, `Color(0xFFE5B130)` border
- no → `Color(0xFFF8D7DA)` bg, `Color(0xFFDC3545)` border

## Common commands

```bash
flutter pub get                            # install dependencies
flutter run                                # run (production backend)
flutter run --release                      # release build — use this to test real performance
flutter run -d macos                       # macOS desktop target
flutter analyze --no-pub                   # static analysis
ipconfig getifaddr en0                     # get local IP for physical device testing
```

## Known gotchas

- **Debug builds are 5–10× slower** than release. Always use `--release` for performance testing.
- **Render cold starts** cause the first API call to take 30–60 s. Not a Flutter bug.
- `withOpacity()` is deprecated in Flutter 3.x — use `.withValues(alpha: ...)`. The codebase still uses `withOpacity` in many places; it still works but triggers analyzer warnings.
- Multi-day events are displayed on every spanned day by iterating from `startDate` to `endDate` in `calendar_screen.dart`. Don't replace this with a single-day key lookup.
- `extra:` in GoRouter is not type-safe — always null-check before casting (`widget.extra is EventPoll ? widget.extra as EventPoll : null`).
