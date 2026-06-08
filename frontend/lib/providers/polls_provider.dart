import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../models/poll.dart';
import '../services/api_service.dart';
import '../services/device_calendar_service.dart';
import '../services/local_notification_service.dart';
import '../services/websocket_service.dart';
import 'events_provider.dart';

class PollsNotifier extends StateNotifier<AsyncValue<List<EventPoll>>> {
  PollsNotifier(this.ref, this.calendarId) : super(const AsyncValue.loading()) {
    fetch();
    _ws.addListener(_onWsMessage);
    _ws.subscribeToCalendar(calendarId);
  }

  final Ref ref;
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
    List<PollVoteOptionInput>? voteOptions,
    String? icon,
    String? color,
  }) async {
    try {
      final poll = await _api.createPoll(
        calendarId: calendarId,
        title: title,
        description: description,
        options: options,
        voteOptions: voteOptions,
        icon: icon,
        color: color,
      );
      state.whenData((list) => state = AsyncValue.data([poll, ...list]));
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
          list.map((p) => p.id == pollId ? updated : p).toList(),
        );
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmPoll({
    required String pollId,
    required String optionId,

    /// Minutes before the created event to fire a reminder notification.
    /// Pass null to skip the reminder.
    int? reminderMinutes = 30,
  }) async {
    try {
      final data = await _api.confirmPoll(pollId: pollId, optionId: optionId);
      final updated = EventPoll.fromJson(data['poll'] as Map<String, dynamic>);
      state.whenData((list) {
        state = AsyncValue.data(
          list.map((p) => p.id == pollId ? updated : p).toList(),
        );
      });

      // Inject the new event directly into eventsProvider (reliable regardless
      // of whether the NOTIFY/WebSocket path delivers event_created in time).
      final eventJson = data['event'];
      if (eventJson != null) {
        final event = CalendarEvent.fromJson(eventJson as Map<String, dynamic>);
        ref.read(eventsProvider(calendarId).notifier).injectEvent(event);
        DeviceCalendarService().syncEvent(event);
        LocalNotificationService().scheduleEventReminder(
          event,
          reminderMinutes: reminderMinutes,
        );
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
        state = AsyncValue.data(list.where((p) => p.id != pollId).toList());
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

final pollsProvider =
    StateNotifierProvider.family<
      PollsNotifier,
      AsyncValue<List<EventPoll>>,
      String
    >((ref, calendarId) => PollsNotifier(ref, calendarId));
