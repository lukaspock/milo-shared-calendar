import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
export '../models/event.dart' show RecurrenceRule;
import '../services/api_service.dart';
import '../services/device_calendar_service.dart';
import '../services/websocket_service.dart';

class EventsNotifier extends StateNotifier<AsyncValue<List<CalendarEvent>>> {
  EventsNotifier(this.calendarId) : super(const AsyncValue.loading()) {
    fetch();
    _listenToWebSocket();
  }

  final String calendarId;
  final _api = ApiService();
  final _ws = WebSocketService();

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.get('/calendars/$calendarId/events');
      final list = (res.data as List)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
        if (recurrenceRule != RecurrenceRule.none)
          'recurrence_rule': recurrenceRule.apiValue,
        if (recurrenceEnd != null)
          'recurrence_end': recurrenceEnd.toIso8601String().substring(0, 10),
      });
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      state.whenData((list) {
        if (!list.any((e) => e.id == event.id)) {
          state = AsyncValue.data([...list, event]..sort((a, b) => a.startTime.compareTo(b.startTime)));
        }
      });
      // Fire-and-forget: sync to device calendar if enabled
      DeviceCalendarService().syncEvent(event);
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
    RecurrenceRule? recurrenceRule,
    DateTime? recurrenceEnd,
    bool clearRecurrence = false,
  }) async {
    try {
      final res = await _api.put('/events/$id', data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        if (color != null) 'color': color,
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule.apiValue,
        if (clearRecurrence) 'recurrence_rule': null,
        if (recurrenceEnd != null)
          'recurrence_end': recurrenceEnd.toIso8601String().substring(0, 10),
      });
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      state.whenData((list) {
        state = AsyncValue.data(list.map((e) => e.id == id ? event : e).toList());
      });
      // Fire-and-forget: sync update to device calendar if enabled
      DeviceCalendarService().syncEvent(event);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      await _api.delete('/events/$id');
      state.whenData((list) {
        state = AsyncValue.data(list.where((e) => e.id != id).toList());
      });
      // Fire-and-forget: remove from device calendar if enabled
      DeviceCalendarService().deleteDeviceEvent(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> notifyMembers(String calendarId, String eventId) async {
    await _api.post('/events/$eventId/notify');
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
