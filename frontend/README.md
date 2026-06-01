# SharedCal Frontend

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
├── models/                CalendarModel, CalendarEvent, AppUser, ...
├── services/              ApiService (Dio), AuthService, WebSocketService
├── providers/             Riverpod state — auth, calendars, events, polls
└── screens/               All UI screens
```

## Known issues

- **Google Sign In / Sign Up is currently non-functional.** `ios/Runner/Info.plist` still contains the placeholder `REPLACE_WITH_REVERSED_CLIENT_ID` for `CFBundleURLSchemes`. Create an iOS OAuth client in Google Cloud Console (bundle ID `com.sharedcal.sharedCal`) and replace it with the reversed client ID to enable Google authentication.
- Google Calendar sync (connecting your personal Google Calendar via the in-app banner) is unaffected and works fine.
