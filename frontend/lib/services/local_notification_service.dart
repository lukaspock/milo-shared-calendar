import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
/// This is purely local — no push servers (FCM/APNs) involved. The app must be
/// running (foreground or background, depending on OS) to receive the WS
/// message and surface the notification.
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _ws = WebSocketService();

  bool _initialized = false;
  int _nextId = 0;

  static const _channelId = 'event_notifications';
  static const _channelName = 'Event notifications';
  static const _channelDescription =
      'Notifies you when a new event is added to one of your calendars.';

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
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    try {
      await _plugin.initialize(settings);
    } catch (_) {
      // Plugin not available on this platform (e.g. some desktop builds) — the
      // WS listener stays harmless because show() will simply no-op.
    }

    _ws.addListener(_onWsMessage);
  }

  /// Requests OS permission to show notifications. Returns true if granted.
  /// Call this when the user chooses on-device notifications.
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? true;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true);
        return granted ?? false;
      }

      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macos != null) {
        final granted = await macos.requestPermissions(
            alert: true, badge: true, sound: true);
        return granted ?? false;
      }
    } catch (_) {
      // ignore — treat as not granted
    }
    return false;
  }

  /// Displays a local notification immediately.
  Future<void> show(String title, String body) async {
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
      await _plugin.show(_nextId++, title, body, details);
    } catch (_) {
      // Never let notification failures bubble into the app flow.
    }
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if (msg['type'] != 'event_created') return;

    final user = AuthService().cachedUser;
    // Only users who opted into on-device notifications get a popup.
    if (user == null || user.notificationType != NotificationType.push) return;

    final event = msg['event'];
    if (event is! Map) return;

    // Don't notify the creator about their own event.
    final createdBy = event['created_by'];
    if (createdBy != null && createdBy == user.id) return;

    final title = (event['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    final creator = (event['creator_name'] as String?)?.trim();

    show(
      'New event',
      creator != null && creator.isNotEmpty
          ? '$creator added "$title"'
          : '"$title" was added to your calendar',
    );
  }
}
