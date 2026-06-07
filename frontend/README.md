# Milo Frontend

Flutter app targeting iOS, Android, and macOS.

## Running

```bash
# Install dependencies
flutter pub get

# Run against production backend (default)
flutter run

# Release build — always use this for performance testing
flutter run --release

# macOS desktop
flutter run -d macos

# Physical device against local backend
flutter run --dart-define=API_HOST=<your-mac-ip>

# Against production backend explicitly
flutter run --dart-define=API_HOST=api.milocalendar.tech
```

See the root [CLAUDE.md](../CLAUDE.md) for device setup, IP config, and Render cold-start notes.

## Project structure

```
lib/
├── main.dart              Entry point
├── app.dart               Router + MaterialApp
├── theme/app_theme.dart   Design tokens, CalHue palette, StickerTile
├── models/                CalendarModel, CalendarEvent, AppUser, EventReaction, ...
├── services/              ApiService (Dio + Cloudinary upload), AuthService, WebSocketService
├── providers/             Riverpod state — auth, calendars, events, polls
└── screens/               All UI screens
```

## Key packages

| Package | Purpose |
|---------|---------|
| `dio` | HTTP client + interceptors |
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `google_fonts` | Plus Jakarta Sans typeface |
| `emoji_picker_flutter` | Full emoji keyboard for reactions and event icons |
| `image_picker` | Gallery/camera access for profile photo and event icon upload |
| `device_calendar` | Read/write native iOS/Android calendar (device calendar sharing) |
| `flutter_local_notifications` | On-device event reminders |
| `shared_preferences` | Persist JWT + cached user |
| `web_socket_channel` | Real-time WebSocket connection |
| `url_launcher` | Open Google OAuth in browser |

## Cloudinary uploads

All media uploads go directly from the device to Cloudinary (unsigned preset `avatars`, cloud `dvlvgosxk`) — no API secret is required or stored in the app.

| Type | Folder | Trigger |
|------|--------|---------|
| Profile avatar | `avatars/` | `PATCH /auth/me` |
| Event icon (photo) | `event_icons/` | Create / edit event |
| Photo memory | `event_photos/` | Add photo to event |

## Known issues

- **Google Sign In / Sign Up is currently non-functional.** `ios/Runner/Info.plist` still contains the placeholder `REPLACE_WITH_REVERSED_CLIENT_ID` for `CFBundleURLSchemes`. Create an iOS OAuth client in Google Cloud Console (bundle ID `com.sharedcal.sharedCal`) and replace it with the reversed client ID to enable Google authentication.
- Google Calendar sync (connecting your personal Google Calendar via the in-app banner) is unaffected and works fine.
