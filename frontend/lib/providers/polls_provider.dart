import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/device_calendar_service.dart';
import '../services/websocket_service.dart';

class PollsNotifier extends StateNotifier<AsyncValue<List<EventPoll>>> {
  PollsNotifier(this.calendarId) : super(const AsyncValue.loading()) {
    fetch();
    _ws.addListener(_onWsMessage);
    _ws.subscribeToCalendar(calendarId);
  }

  final String calendarId;
  final _api = ApiService();
  final _ws = WebSocketService();

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final list = await _api.fetchPolls(calendarId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'poll_update' && msg['calendar_id'] == calendarId) {
      fetch();
    }
  }

  Future<EventPoll?> createPoll({
    required String title,
    String? description,
    required List<PollOptionInput> options,
  }) async {
    try {
      final poll = await _api.createPoll(
        calendarId: calendarId,
        title: title,
        description: description,
        options: options,
      );
      state.whenData(
          (list) => state = AsyncValue.data([poll, ...list]));
      return poll;
    } catch (_) {
      return null;
    }
  }

  Future<bool> vote({
    required String pollId,
    required String optionId,
    required String vote,
  }) async {
    try {
      final updated = await _api.votePoll(
        pollId: pollId,
        optionId: optionId,
        vote: vote,
      );
      state.whenData((list) {
        state = AsyncValue.data(
            list.map((p) => p.id == pollId ? updated : p).toList());
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmPoll({
    required String pollId,
    required String optionId,
  }) async {
    try {
      final data = await _api.confirmPoll(
        pollId: pollId,
        optionId: optionId,
      );
      final updated = EventPoll.fromJson(data['poll'] as Map<String, dynamic>);
      state.whenData((list) {
        state = AsyncValue.data(
            list.map((p) => p.id == pollId ? updated : p).toList());
      });

      // Sync the newly created event to device calendar.
      // Google Calendar is already handled server-side via syncEventCreated.
      final eventJson = data['event'];
      if (eventJson != null) {
        final event =
            CalendarEvent.fromJson(eventJson as Map<String, dynamic>);
        DeviceCalendarService().syncEvent(event);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePoll(String pollId) async {
    try {
      await _api.deletePoll(pollId);
      state.whenData((list) {
        state =
            AsyncValue.data(list.where((p) => p.id != pollId).toList());
      });
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

final pollsProvider = StateNotifierProvider.family<PollsNotifier,
    AsyncValue<List<EventPoll>>, String>(
  (_, calendarId) => PollsNotifier(calendarId),
);
