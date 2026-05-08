import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

class CalendarNotifier extends StateNotifier<AsyncValue<List<CalendarModel>>> {
  CalendarNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
    _ws.addListener(_onWsMessage);
  }

  final Ref ref;
  final _api = ApiService();
  final _ws = WebSocketService();

  void _onWsMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'member_joined') {
      final calendarId = msg['calendar_id'] as String?;
      final memberCount = msg['member_count'] as int?;
      if (calendarId == null || memberCount == null) return;
      state.whenData((list) {
        state = AsyncValue.data(list.map((c) {
          if (c.id == calendarId) return c.copyWithMemberCount(memberCount);
          return c;
        }).toList());
      });
    }
  }

  @override
  void dispose() {
    _ws.removeListener(_onWsMessage);
    super.dispose();
  }

  Future<void> fetch() async {
    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final res = await _api.get('/calendars');
      final list = (res.data as List)
          .map((e) => CalendarModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CalendarModel?> createCalendar(String name) async {
    try {
      final res = await _api.post('/calendars', data: {'name': name});
      final calendar =
          CalendarModel.fromJson(res.data as Map<String, dynamic>);
      state.whenData((list) {
        state = AsyncValue.data([calendar, ...list]);
      });
      return calendar;
    } catch (_) {
      return null;
    }
  }

  Future<CalendarModel?> joinCalendar(String inviteCode) async {
    try {
      final res = await _api.post('/calendars/join', data: {'invite_code': inviteCode});
      final calendar =
          CalendarModel.fromJson(res.data as Map<String, dynamic>);
      state.whenData((list) {
        state = AsyncValue.data([calendar, ...list]);
      });
      return calendar;
    } catch (_) {
      return null;
    }
  }

  Future<List<CalendarMember>> getMembers(String calendarId) async {
    final res = await _api.get('/calendars/$calendarId/members');
    return (res.data as List)
        .map((e) => CalendarMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> kickMember(String calendarId, String userId) async {
    try {
      await _api.delete('/calendars/$calendarId/members/$userId');
      return true;
    } catch (_) {
      return false;
    }
  }
}

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, AsyncValue<List<CalendarModel>>>(
  (ref) {
    // Re-create the notifier whenever auth status changes
    ref.watch(authProvider.select((s) => s.status));
    return CalendarNotifier(ref);
  },
);

// Currently selected calendar ID
final selectedCalendarProvider = StateProvider<String?>((_) => null);
