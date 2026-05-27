import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../services/api_service.dart';
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
  }) async {
    try {
      final res = await _api.post('/events', data: {
        'calendar_id': calendarId,
        'title': title,
        'description': description,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        if (color != null) 'color': color,
      });
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      state.whenData((list) {
        if (!list.any((e) => e.id == event.id)) {
          state = AsyncValue.data([...list, event]..sort((a, b) => a.startTime.compareTo(b.startTime)));
        }
      });
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
  }) async {
    try {
      final res = await _api.put('/events/$id', data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        if (color != null) 'color': color,
      });
      final event = CalendarEvent.fromJson(res.data as Map<String, dynamic>);
      state.whenData((list) {
        state = AsyncValue.data(list.map((e) => e.id == id ? event : e).toList());
      });
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
