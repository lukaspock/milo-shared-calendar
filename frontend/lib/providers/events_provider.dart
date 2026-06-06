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
  }

  final String calendarId;
  final _api = ApiService();
  final _ws = WebSocketService();
  final _cache = CacheService();

  // Tracks API events (SharedCal + Google imports) and device events separately.
  // State is always their union; device events survive WebSocket updates.
  List<CalendarEvent> _apiEvents = [];
  List<CalendarEvent> _deviceEvents = [];

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

      // Load device calendar events (no-op on macOS, no-op if not enabled)
      _deviceEvents = await DeviceCalendarService().readExternalEvents(
        sharedCalendarId: calendarId,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        endDate: DateTime.now().add(const Duration(days: 365)),
      );

      _setMergedState();
    } catch (e, st) {
      if (cached == null) state = AsyncValue.error(e, st);
    }
  }

  void _listenToWebSocket() {
    _ws.addListener(_onWsMessage);
    _ws.subscribeToCalendar(calendarId);
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'event_created') {
      final event = CalendarEvent.fromJson(msg['event'] as Map<String, dynamic>);
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
      final event = CalendarEvent.fromJson(msg['event'] as Map<String, dynamic>);
      if (event.calendarId != calendarId) return;
      _apiEvents = _apiEvents.map((e) => e.id == event.id ? event : e).toList();
      _setMergedState();
    } else if (type == 'event_deleted') {
      final eventId = msg['event_id'] as String;
      final cal = msg['calendar_id'] as String;
      if (cal != calendarId) return;
      _apiEvents = _apiEvents.where((e) => e.id != eventId).toList();
      _setMergedState();
    } else if (type == 'event_starting' || type == 'event_ended') {
      final cal = msg['calendar_id'] as String?;
      if (cal != calendarId) return;
      _setMergedState();
    }
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
  }) async {
    try {
      final res = await _api.post('/events', data: {
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
      });
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      if (!_apiEvents.any((e) => e.id == event.id)) {
        _apiEvents = [..._apiEvents, event]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        _cache.saveEvents(calendarId, _apiEvents);
        _setMergedState();
      }
      // Fire-and-forget: sync to device calendar + schedule reminder
      DeviceCalendarService().syncEvent(event);
      LocalNotificationService().scheduleEventReminder(event);
      return event;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateEvent(String id, {
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
  }) async {
    try {
      final res = await _api.put('/events/$id', data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        if (color != null) 'color': color,
        'icon': icon, // always send (null clears it)
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule.apiValue,
        if (clearRecurrence) 'recurrence_rule': null,
        if (recurrenceEnd != null)
          'recurrence_end': recurrenceEnd.toIso8601String().substring(0, 10),
        if (editAll) 'edit_all': true,
      });
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
      LocalNotificationService().scheduleEventReminder(event);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEvent(String id, {bool deleteAll = false}) async {
    try {
      await _api.delete('/events/$id',
          data: deleteAll ? {'delete_all': true} : null);
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
    _ws.removeListener(_onWsMessage);
    super.dispose();
  }
}

final eventsProvider = StateNotifierProvider.family<EventsNotifier,
    AsyncValue<List<CalendarEvent>>, String>(
  (_, calendarId) => EventsNotifier(calendarId),
);
