import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app.dart';
import '../models/event.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'websocket_service.dart';

/// Shows on-device (local) notifications when a new event is created in one of
/// the user's calendars — but only for users whose notification preference is
/// [NotificationType.push].
///
/// How it works: the backend already broadcasts `event_created` over the
/// WebSocket for real-time sync. This service registers one global WS listener
/// (set up once in [init]) and, when an event created by *someone else* arrives,
/// pops a local notification via flutter_local_notifications.
///
/// Notification ID ranges (to avoid cancellation collisions):
///   0 – 16 777 215  scheduled reminders (derived from event UUID hex)
///   20 000 000 – 29 999 999  chat notifications (stable per calendar)
///   timestamp-based  ephemeral event/reminder alerts (never collide with above)
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _ws = WebSocketService();

  bool _initialized = false;

  // Pending navigation route queued from a notification tap that launched the
  // app from terminated state (router not ready yet at that point).
  static String? _pendingRoute;

  static const _channelId = 'event_notifications';
  static const _channelName = 'Event notifications';
  static const _channelDescription =
      'Notifies you when a new event is added to one of your calendars.';

  /// Consume a route stored from a notification tap that launched the app from
  /// terminated state. Call this once from HomeScreen / SplashScreen.
  static String? consumePendingRoute() {
    final r = _pendingRoute;
    _pendingRoute = null;
    return r;
  }

  /// Initializes the plugin and wires up the global WebSocket listener.
  /// Safe to call multiple times — only the first call does work.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      // Don't prompt on launch — we request explicitly when the user opts in.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // Show notifications even when the app is in the foreground.
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    tz.initializeTimeZones();

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Handle tap that launched the app from terminated state.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _handlePayload(launchDetails!.notificationResponse?.payload);
      }
    } catch (_) {
      // Plugin not available on this platform (e.g. some desktop builds).
    }

    _ws.addListener(_onWsMessage);
  }

  /// Routes a notification tap payload to the correct screen.
  static void _onNotificationTapped(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  static void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final calendarId = data['calendarId'] as String?;
      final eventId = data['eventId'] as String?;
      if (calendarId == null) return;

      final route = eventId != null
          ? '/calendar/$calendarId/event/$eventId'
          : '/calendar/$calendarId';

      try {
        appRouter.go(route);
      } catch (_) {
        // Router not ready yet (terminated-state launch) — store for later.
        _pendingRoute = route;
      }
    } catch (_) {}
  }

  /// Requests OS permission to show notifications. Returns true if granted.
  /// Call this when the user chooses on-device notifications.
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final granted = await macos.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (_) {
      // ignore — treat as not granted
    }
    return false;
  }

  /// Returns a notification ID that won't collide with scheduled reminders
  /// (which live in [0, 16 777 215]) or chat notifications ([20M, 30M)).
  /// Timestamp-based — effectively unique for human-scale usage.
  static int _ephemeralId() =>
      DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

  /// Stable notification ID for a calendar's chat notifications.
  /// All messages from the same calendar share one ID so new messages
  /// replace the old notification rather than stacking up.
  static int _chatIdFor(String calendarId) {
    final hex = calendarId.replaceAll('-', '');
    return 20_000_000 + int.parse(hex.substring(0, 5), radix: 16) % 10_000_000;
  }

  /// Stable ID for a scheduled event reminder, derived from the event UUID.
  /// Lives in [0, 16 777 215] — well within int32 range.
  static int _reminderIdFor(String eventId) {
    final hex = eventId.replaceAll('-', '');
    return int.parse(hex.substring(0, 6), radix: 16);
  }

  /// Displays a local notification immediately.
  Future<void> show(String title, String body, {String? payload}) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(
        _ephemeralId(),
        title,
        body,
        details,
        payload: payload,
      );
    } catch (_) {
      // Never let notification failures bubble into the app flow.
    }
  }

  /// Displays a chat message notification with optional sender avatar as large icon.
  Future<void> showChatNotification({
    required String calendarId,
    required String title,
    required String body,
    Uint8List? largeIconBytes,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat',
      channelDescription: 'New chat messages',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      largeIcon: largeIconBytes != null
          ? ByteArrayAndroidBitmap(largeIconBytes)
          : null,
    );
    const iosDetails = DarwinNotificationDetails();
    const macosDetails = DarwinNotificationDetails();
    final payload = jsonEncode({'calendarId': calendarId});
    try {
      await _plugin.show(
        _chatIdFor(calendarId),
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          macOS: macosDetails,
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  // ── Reminder preferences (per-event, stored locally) ─────────────────────

  /// Persists [minutes] (or null = no reminder) for [eventId] in SharedPreferences.
  Future<void> saveReminderPreference(String eventId, int? minutes) async {
    final prefs = await SharedPreferences.getInstance();
    if (minutes == null) {
      await prefs.remove('reminder_$eventId');
    } else {
      await prefs.setInt('reminder_$eventId', minutes);
    }
  }

  /// Returns the saved reminder preference for [eventId], or null if none.
  Future<int?> loadReminderPreference(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_$eventId');
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Schedules a local notification [reminderMinutes] before [event] starts.
  ///
  /// Pass `reminderMinutes: null` to skip scheduling (no reminder).
  /// Saves the preference so it can be restored when the event is edited.
  /// No-op if the reminder time is already in the past.
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    int? reminderMinutes = 30,
  }) async {
    if (reminderMinutes == null) {
      await saveReminderPreference(event.id, null);
      return;
    }

    await init();
    final user = AuthService().cachedUser;
    if (user == null || user.notificationType != NotificationType.push) return;

    final reminderTime = event.startTime.subtract(
      Duration(minutes: reminderMinutes),
    );
    if (!reminderTime.isAfter(DateTime.now())) return;

    await saveReminderPreference(event.id, reminderMinutes);

    final label = _reminderLabel(reminderMinutes);
    final payload = jsonEncode({
      'calendarId': event.calendarId,
      'eventId': event.id,
    });
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'event_reminders',
        'Event reminders',
        channelDescription: 'Reminds you before an event starts.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        _reminderIdFor(event.id),
        label,
        event.title,
        tz.TZDateTime.from(reminderTime, tz.local),
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Scheduled notifications may not be supported on all platforms/configs.
    }
  }

  /// Human-readable notification title for a given reminder lead time.
  static String _reminderLabel(int minutes) {
    if (minutes < 60) return 'Starting in $minutes minutes';
    if (minutes == 60) return 'Starting in 1 hour';
    if (minutes < 1440) return 'Starting in ${minutes ~/ 60} hours';
    return 'Starting tomorrow';
  }

  /// Cancels a previously scheduled reminder for the given event ID.
  Future<void> cancelEventReminder(String eventId) async {
    try {
      await _plugin.cancel(_reminderIdFor(eventId));
    } catch (_) {}
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    if (type == 'event_reminder') {
      final user = AuthService().cachedUser;
      if (user == null || user.notificationType != NotificationType.push) {
        return;
      }

      final title = (msg['event_title'] as String?)?.trim();
      if (title == null || title.isEmpty) return;

      // Compute lead-time label from the actual start_time if available,
      // falling back to "30 minutes" if the field is missing.
      String label = 'Starting in 30 minutes';
      final startTimeStr = msg['start_time'] as String?;
      if (startTimeStr != null) {
        try {
          final startTime = DateTime.parse(startTimeStr).toLocal();
          final mins = startTime.difference(DateTime.now()).inMinutes;
          if (mins > 0) label = _reminderLabel(mins);
        } catch (_) {}
      }

      final calendarId = msg['calendar_id'] as String?;
      final eventId = msg['event_id'] as String?;
      final payload = calendarId != null
          ? jsonEncode({
              'calendarId': calendarId,
              if (eventId != null) 'eventId': eventId,
            })
          : null;

      show(label, title, payload: payload);
      return;
    }

    if (type != 'event_created') return;

    final user = AuthService().cachedUser;
    if (user == null || user.notificationType != NotificationType.push) return;

    final event = msg['event'];
    if (event is! Map) return;

    final createdBy = event['created_by'];
    if (createdBy != null && createdBy == user.id) return;

    final title = (event['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    final creator = (event['creator_name'] as String?)?.trim();
    final calendarId = event['calendar_id'] as String?;
    final eventId = event['id'] as String?;

    final payload = calendarId != null
        ? jsonEncode({
            'calendarId': calendarId,
            if (eventId != null) 'eventId': eventId,
          })
        : null;

    show(
      'New event',
      creator != null && creator.isNotEmpty
          ? '$creator added "$title"'
          : '"$title" was added to your calendar',
      payload: payload,
    );
  }
}
