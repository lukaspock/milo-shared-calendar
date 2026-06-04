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

  Future<void> fetch() async {
    // Load from cache first — instant paint, no spinner on Render cold starts
    final cached = await _cache.loadEvents(calendarId);
    if (cached != null) {
      state = AsyncValue.data(cached);
    } else {
      state = const AsyncValue.loading();
    }

    try {
      final res = await _api.get('/calendars/$calendarId/events');
      final list = (res.data as List)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
      _cache.saveEvents(calendarId, list);
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
      state.whenData((list) {
        if (list.any((e) => e.id == event.id)) return;
        state = AsyncValue.data([...list, event]..sort((a, b) => a.startTime.compareTo(b.startTime)));
      });
      // Sync to device calendar for ANY new event arriving via WebSocket —
      // covers poll-confirmed events and events created by other members.
      // DeviceCalendarService is idempotent so calling it twice is safe.
      DeviceCalendarService().syncEvent(event);
    } else if (type == 'event_updated') {
      final event = CalendarEvent.fromJson(msg['event'] as Map<String, dynamic>);
      if (event.calendarId != calendarId) return;
      state.whenData((list) {
        state = AsyncValue.data(list.map((e) => e.id == event.id ? event : e).toList());
      });
    } else if (type == 'event_deleted') {
      final eventId = msg['event_id'] as String;
      final cal = msg['calendar_id'] as String;
      if (cal != calendarId) return;
      state.whenData((list) {
        state = AsyncValue.data(list.where((e) => e.id != eventId).toList());
      });
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
      state.whenData((list) {
        if (!list.any((e) => e.id == event.id)) {
          final updated = [...list, event]..sort((a, b) => a.startTime.compareTo(b.startTime));
          state = AsyncValue.data(updated);
          _cache.saveEvents(calendarId, updated);
        }
      });
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
      state.whenData((list) {
        if (editAll) {
          fetch();
        } else {
          final updated = list.map((e) => e.id == id ? event : e).toList();
          state = AsyncValue.data(updated);
          _cache.saveEvents(calendarId, updated);
        }
      });
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
      state.whenData((list) {
        if (deleteAll) {
          fetch();
        } else {
          final updated = list.where((e) => e.id != id).toList();
          state = AsyncValue.data(updated);
          _cache.saveEvents(calendarId, updated);
        }
      });
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
