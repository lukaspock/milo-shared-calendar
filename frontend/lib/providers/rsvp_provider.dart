import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rsvp.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class RsvpNotifier extends StateNotifier<AsyncValue<Map<String, RsvpSummary>>> {
  RsvpNotifier(this.calendarId) : super(const AsyncValue.loading()) {
    fetch();
    _ws.addListener(_onWsMessage);
    _ws.subscribeToCalendar(calendarId);
  }

  final String calendarId;
  final _api = ApiService();
  final _ws = WebSocketService();

  Future<void> fetch() async {
    try {
      final map = await _api.getCalendarRsvps(calendarId);
      state = AsyncValue.data(map);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'rsvp_update' && msg['calendar_id'] == calendarId) {
      fetch();
    }
  }

  @override
  void dispose() {
    _ws.removeListener(_onWsMessage);
    super.dispose();
  }
}

final rsvpProvider =
    StateNotifierProvider.family<
      RsvpNotifier,
      AsyncValue<Map<String, RsvpSummary>>,
      String
    >((ref, calendarId) => RsvpNotifier(calendarId));
