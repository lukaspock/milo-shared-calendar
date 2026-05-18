# Frontend — SharedCal Flutter App

Flutter app targeting Android, iOS, and macOS. State management via Riverpod, navigation via go_router, HTTP via Dio, real-time updates via WebSocket.

## Key dependencies

| Package               | Purpose                                      |
|-----------------------|----------------------------------------------|
| `flutter_riverpod`    | State management                             |
| `go_router`           | Declarative routing                          |
| `dio`                 | HTTP client with JWT interceptor             |
| `web_socket_channel`  | WebSocket for real-time calendar updates     |
| `shared_preferences`  | Persist JWT token and user data              |
| `google_fonts`        | Plus Jakarta Sans throughout                 |
| `table_calendar`      | Calendar widget on `CalendarScreen`          |
| `intl`                | Date formatting                              |

## Project layout

```
lib/
├── main.dart                  Entry point — loads hue prefs, runs app
├── app.dart                   GoRouter config + MaterialApp.router
├── theme/app_theme.dart       Design tokens, CalHue palette, StickerTile widget
├── models/                    Plain Dart data classes (fromJson / copyWith)
├── services/
│   ├── api_service.dart       Dio singleton — injects Bearer token on every request
│   ├── auth_service.dart      Login/register/logout + SharedPreferences session
│   └── websocket_service.dart Singleton WS client with auth + subscribe flow
├── providers/
│   ├── auth_provider.dart     AuthNotifier (loading → authenticated/unauthenticated)
│   ├── calendar_provider.dart CalendarNotifier — re-created on auth status change
│   └── events_provider.dart   Events per calendar
├── screens/                   One file per route
└── widgets/                   Shared UI components
```

## Routing

| Path                              | Screen               |
|-----------------------------------|----------------------|
| `/`                               | SplashScreen         |
| `/login`                          | LoginScreen          |
| `/register`                       | RegisterScreen       |
| `/home`                           | HomeScreen           |
| `/calendar/:calendarId`           | CalendarScreen       |
| `/calendar/:calendarId/event/:id` | EventDetailScreen    |

## Backend URL

The backend host is configured at build time via `--dart-define`:

```bash
# macOS desktop — defaults to 127.0.0.1
flutter run -d macos

# Physical device — pass Mac's local network IP
flutter run --dart-define=API_HOST=192.168.1.42
```

`API_HOST` defaults to `127.0.0.1` if not provided. Defined in:
- `lib/services/api_service.dart` → `http://$_apiHost:3000`
- `lib/services/websocket_service.dart` → `ws://$_apiHost:3000/ws`

## State management patterns

- All providers are `StateNotifierProvider`. Read with `ref.read`, watch with `ref.watch`.
- `calendarProvider` watches `authProvider.select((s) => s.status)` — automatically re-created and re-fetches when auth status changes.
- `ApiService` and `WebSocketService` are singletons (`factory` constructors).

## Design system

All colors live in `AppTheme` (`theme/app_theme.dart`). Never hardcode hex values.

| Token              | Value       | Usage              |
|--------------------|-------------|--------------------|
| `AppTheme.bg`      | `#FFF8F0`   | Scaffold background |
| `AppTheme.surface` | `#FFFFFF`   | Cards, sheets      |
| `AppTheme.ink`     | `#1F1B16`   | Primary text       |
| `AppTheme.inkMuted`| `#A39A8C`   | Secondary text     |
| `AppTheme.line`    | `#EFE4D2`   | Borders, dividers  |

Calendar cards use `CalHue` (8 pastel hues in `stickerHues`). Use `hueFor(calendar)` to resolve a calendar's hue. Use `persistCalendarHue` to save a user's choice.

## Common commands

```bash
flutter pub get       # install dependencies
flutter run -d macos  # run on macOS desktop
flutter analyze       # static analysis
flutter run --dart-define=API_HOST=  # run with custom API host
ipconfig getifaddr en0  # get local IP address to insert into API_HOST
```
