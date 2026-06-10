import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
export '../models/event.dart' show RecurrenceRule;
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/device_calendar_service.dart';
import '../services/local_notification_service.dart';
import '../services/websocket_service.dart';

class EventsNotifier extends StateNotifier<AsyncValue<List<CalendarEvent>>> {
  EventsNotifier(this.calendarId) : super(const AsyncValue.loading()) {
    fetch();
    _listenToWebSocket();
    _deviceSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _periodicDeviceSync(),
    );
  }

  final String calendarId;
  final _api = ApiService();
  final _ws = WebSocketService();
  final _cache = CacheService();

  // Tracks API events (SharedCal + Google imports) and device events separately.
  // State is always their union; device events survive WebSocket updates.
  List<CalendarEvent> _apiEvents = [];
  List<CalendarEvent> _deviceEvents = [];

  // IDs of device events uploaded in the last sync — used to skip uploads
  // when nothing has changed and avoid unnecessary device_synced broadcasts.
  Set<String> _lastUploadedDeviceIds = {};

  Timer? _deviceSyncTimer;

  void _setMergedState() {
    state = AsyncValue.data([..._apiEvents, ..._deviceEvents]);
  }

  Future<void> fetch() async {
    // Load from cache first — instant paint, no spinner on Render cold starts
    final cached = await _cache.loadEvents(calendarId);
    if (cached != null) {
      _apiEvents = cached;
      _setMergedState();
    } else {
      state = const AsyncValue.loading();
    }

    try {
      final res = await _api.get('/calendars/$calendarId/events');
      final list = (res.data as List)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      _apiEvents = list;
      _cache.saveEvents(calendarId, list);

      debugPrint(
        '[DeviceSync] fetch(): API returned ${list.length} events '
        '(${list.where((e) => e.source == EventSource.deviceImport).length} device_import, '
        '${list.where((e) => e.source == EventSource.googleImport).length} google_import)',
      );

      // Load device calendar events from the local device
      final localDeviceEvents = await DeviceCalendarService()
          .readExternalEvents(
            sharedCalendarId: calendarId,
            startDate: DateTime.now().subtract(const Duration(days: 365)),
            endDate: DateTime.now().add(const Duration(days: 365)),
          );

      debugPrint(
        '[DeviceSync] fetch(): localDeviceEvents=${localDeviceEvents.length} '
        'lastUploadedIds=${_lastUploadedDeviceIds.length}',
      );

      // Upload this user's device events to the backend so other members can see them.
      // Only upload when the set of IDs changed — prevents a cascade loop where
      // device_synced → fetch() → upload → device_synced → fetch() → ...
      final currentDeviceIds = localDeviceEvents.map((e) => e.id).toSet();
      final idsChanged =
          currentDeviceIds.length != _lastUploadedDeviceIds.length ||
          !_lastUploadedDeviceIds.containsAll(currentDeviceIds);
      debugPrint(
        '[DeviceSync] fetch(): currentIds=${currentDeviceIds.length} idsChanged=$idsChanged',
      );
      if (idsChanged) {
        _lastUploadedDeviceIds = currentDeviceIds;
        if (localDeviceEvents.isNotEmpty) {
          debugPrint(
            '[DeviceSync] fetch(): triggering upload of ${localDeviceEvents.length} events',
          );
          _uploadDeviceEvents(localDeviceEvents);
        } else {
          debugPrint('[DeviceSync] fetch(): no local device events to upload');
        }
      } else {
        debugPrint('[DeviceSync] fetch(): IDs unchanged — skipping upload');
      }

      // Deduplicate: don't show a local device event that the API already returned
      // (happens on subsequent fetches once the backend has persisted and returns it).
      final apiDeviceIds = list
          .where((e) => e.source == EventSource.deviceImport)
          .map((e) => e.id)
          .toSet();
      _deviceEvents = localDeviceEvents
          .where((e) => !apiDeviceIds.contains(e.id))
          .toList();

      debugPrint(
        '[DeviceSync] fetch(): _deviceEvents (local-only, not yet in API)=${_deviceEvents.length}',
      );
      _setMergedState();
    } catch (e, st) {
      debugPrint('[DeviceSync] fetch() ERROR: $e\n$st');
      if (cached == null) state = AsyncValue.error(e, st);
    }
  }

  /// Reads device calendar events and uploads them only when the set of event
  /// IDs has changed since the last upload. Skips silently on macOS.
  Future<void> _periodicDeviceSync() async {
    debugPrint('[DeviceSync] _periodicDeviceSync() — calendarId=$calendarId');
    try {
      final events = await DeviceCalendarService().readExternalEvents(
        sharedCalendarId: calendarId,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now().add(const Duration(days: 365)),
      );
      final currentIds = events.map((e) => e.id).toSet();
      debugPrint(
        '[DeviceSync] _periodicDeviceSync(): currentIds=${currentIds.length} lastUploaded=${_lastUploadedDeviceIds.length}',
      );
      if (currentIds.length == _lastUploadedDeviceIds.length &&
          _lastUploadedDeviceIds.containsAll(currentIds)) {
        debugPrint(
          '[DeviceSync] _periodicDeviceSync(): no change — skipping upload',
        );
        return;
      }
      debugPrint(
        '[DeviceSync] _periodicDeviceSync(): change detected — uploading ${events.length} events',
      );
      _lastUploadedDeviceIds = currentIds;
      _uploadDeviceEvents(events);
    } catch (e, st) {
      debugPrint('[DeviceSync] _periodicDeviceSync() ERROR: $e\n$st');
    }
  }

  /// Uploads [events] (from the local device calendar) to the backend so that
  /// all members of this calendar can see them. Fire-and-forget.
  Future<void> _uploadDeviceEvents(List<CalendarEvent> events) async {
    debugPrint(
      '[DeviceSync] _uploadDeviceEvents(): uploading ${events.length} events to calendarId=$calendarId',
    );
    for (final e in events) {
      final rawId = e.id.startsWith('device_')
          ? e.id.substring('device_'.length)
          : e.id;
      debugPrint(
        '[DeviceSync]   → "${e.title}" device_event_id=$rawId start=${e.startTime.toUtc().toIso8601String()}',
      );
    }
    try {
      final res = await _api.post(
        '/calendars/$calendarId/device-events',
        data: {
          'events': events
              .map(
                (e) => {
                  'device_event_id': e.id.startsWith('device_')
                      ? e.id.substring('device_'.length)
                      : e.id,
                  'title': e.title,
                  'start_time': e.startTime.toUtc().toIso8601String(),
                  'end_time': e.endTime.toUtc().toIso8601String(),
                  if (e.description != null) 'description': e.description,
                },
              )
              .toList(),
        },
      );
      debugPrint(
        '[DeviceSync] _uploadDeviceEvents(): SUCCESS — response=${res.data}',
      );
    } catch (e, st) {
      debugPrint('[DeviceSync] _uploadDeviceEvents() ERROR: $e\n$st');
      // Never let upload errors affect the main UI
    }
  }

  void _listenToWebSocket() {
    _ws.addListener(_onWsMessage);
    _ws.subscribeToCalendar(calendarId);
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'event_created') {
      final event = CalendarEvent.fromJson(
        msg['event'] as Map<String, dynamic>,
      );
      if (event.calendarId != calendarId) return;
      if (!_apiEvents.any((e) => e.id == event.id)) {
        _apiEvents = [..._apiEvents, event]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        _setMergedState();
      }
      // Sync to device calendar for ANY new event via WebSocket — covers
      // poll-confirmed events and events created by other members.
      DeviceCalendarService().syncEvent(event);
    } else if (type == 'event_updated') {
      final event = CalendarEvent.fromJson(
        msg['event'] as Map<String, dynamic>,
      );
      if (event.calendarId != calendarId) return;
      _apiEvents = _apiEvents.map((e) => e.id == event.id ? event : e).toList();
      _setMergedState();
    } else if (type == 'event_deleted') {
      final eventId = msg['event_id'] as String;
      final cal = msg['calendar_id'] as String;
      if (cal != calendarId) return;
      _apiEvents = _apiEvents.where((e) => e.id != eventId).toList();
      _setMergedState();
    } else if (type == 'gcal_synced') {
      final cal = msg['calendar_id'] as String?;
      if (cal != calendarId) return;
      // Backend finished importing Google Calendar events — re-fetch so they
      // appear immediately without the user having to tap refresh manually.
      fetch();
    } else if (type == 'device_synced') {
      final cal = msg['calendar_id'] as String?;
      if (cal != calendarId) return;
      debugPrint(
        '[DeviceSync] WS device_synced received for calendarId=$calendarId — triggering fetch()',
      );
      // A member uploaded their device calendar events — re-fetch so they
      // become visible to all members immediately.
      fetch();
    } else if (type == 'member_color_updated') {
      final cal = msg['calendar_id'] as String?;
      if (cal != calendarId) return;
      final userId = msg['user_id'] as String?;
      final color = msg['color'] as String?;
      if (userId != null && color != null) {
        _updateCreatorColor(userId, color);
      }
    } else if (type == 'event_starting' || type == 'event_ended') {
      final cal = msg['calendar_id'] as String?;
      if (cal != calendarId) return;
      _setMergedState();
    }
  }

  void _updateCreatorColor(String userId, String color) {
    _apiEvents = _apiEvents.map((e) {
      if (e.createdBy == userId) return e.copyWith(creatorColor: color);
      return e;
    }).toList();
    _setMergedState();
  }

  /// Adds an event that arrived via a non-WebSocket path (e.g. poll confirmation
  /// response) directly into state. Deduplicates and updates the cache.
  void injectEvent(CalendarEvent event) {
    if (!_apiEvents.any((e) => e.id == event.id)) {
      _apiEvents = [..._apiEvents, event]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      _cache.saveEvents(calendarId, _apiEvents);
      _setMergedState();
    }
  }

  Future<CalendarEvent?> createEvent({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? color,
    String? icon,
    RecurrenceRule recurrenceRule = RecurrenceRule.none,
    DateTime? recurrenceEnd,

    /// Minutes before the event to fire a reminder notification.
    /// Pass null to skip the reminder entirely.
    int? reminderMinutes = 30,
  }) async {
    try {
      final res = await _api.post(
        '/events',
        data: {
          'calendar_id': calendarId,
          'title': title,
          'description': description,
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          if (color != null) 'color': color,
          if (icon != null) 'icon': icon,
          if (recurrenceRule != RecurrenceRule.none)
            'recurrence_rule': recurrenceRule.apiValue,
          if (recurrenceEnd != null)
            'recurrence_end': recurrenceEnd.toIso8601String().substring(0, 10),
        },
      );
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      if (!_apiEvents.any((e) => e.id == event.id)) {
        _apiEvents = [..._apiEvents, event]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        _cache.saveEvents(calendarId, _apiEvents);
        _setMergedState();
      }
      // Fire-and-forget: sync to device calendar + schedule reminder
      DeviceCalendarService().syncEvent(event);
      LocalNotificationService().scheduleEventReminder(
        event,
        reminderMinutes: reminderMinutes,
      );
      return event;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateEvent(
    String id, {
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? color,
    String? icon,
    RecurrenceRule? recurrenceRule,
    DateTime? recurrenceEnd,
    bool clearRecurrence = false,
    bool editAll = false,

    /// Updated reminder lead time in minutes. Pass null to remove the reminder.
    int? reminderMinutes = 30,
  }) async {
    try {
      final res = await _api.put(
        '/events/$id',
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (startTime != null)
            'start_time': startTime.toUtc().toIso8601String(),
          if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
          if (color != null) 'color': color,
          'icon': icon, // always send (null clears it)
          if (recurrenceRule != null)
            'recurrence_rule': recurrenceRule.apiValue,
          if (clearRecurrence) 'recurrence_rule': null,
          if (recurrenceEnd != null)
            'recurrence_end': recurrenceEnd.toIso8601String().substring(0, 10),
          if (editAll) 'edit_all': true,
        },
      );
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      if (editAll) {
        fetch();
      } else {
        _apiEvents = _apiEvents.map((e) => e.id == id ? event : e).toList();
        _cache.saveEvents(calendarId, _apiEvents);
        _setMergedState();
      }
      // Fire-and-forget: sync update to device calendar + reschedule reminder
      DeviceCalendarService().syncEvent(event);
      LocalNotificationService().cancelEventReminder(id);
      LocalNotificationService().scheduleEventReminder(
        event,
        reminderMinutes: reminderMinutes,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEvent(String id, {bool deleteAll = false}) async {
    try {
      await _api.delete(
        '/events/$id',
        data: deleteAll ? {'delete_all': true} : null,
      );
      if (deleteAll) {
        fetch();
      } else {
        _apiEvents = _apiEvents.where((e) => e.id != id).toList();
        _cache.saveEvents(calendarId, _apiEvents);
        _setMergedState();
      }
      // Fire-and-forget: remove from device calendar + cancel reminder
      DeviceCalendarService().deleteDeviceEvent(id);
      LocalNotificationService().cancelEventReminder(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _deviceSyncTimer?.cancel();
    _ws.removeListener(_onWsMessage);
    super.dispose();
  }
}

final eventsProvider =
    StateNotifierProvider.family<
      EventsNotifier,
      AsyncValue<List<CalendarEvent>>,
      String
    >((_, calendarId) => EventsNotifier(calendarId));
