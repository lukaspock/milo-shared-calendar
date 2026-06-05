import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar.dart';
import '../models/member.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';
import 'auth_provider.dart';

class CalendarNotifier extends StateNotifier<AsyncValue<List<CalendarModel>>> {
  CalendarNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetch();
    _ws.addListener(_onWsMessage);
  }

  final Ref ref;
  final _api = ApiService();
  final _ws = WebSocketService();
  final _cache = CacheService();

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

    // Load from cache first — shows data instantly, even on Render cold starts
    final cached = await _cache.loadCalendars();
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
      for (final c in cached) {
        _ws.subscribeToCalendar(c.id);
      }
    } else {
      state = const AsyncValue.loading();
    }

    try {
      final res = await _api.get('/calendars');
      final list = (res.data as List)
          .map((e) => CalendarModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
      _cache.saveCalendars(list);
      for (final c in list) {
        _ws.subscribeToCalendar(c.id);
      }
    } catch (e, st) {
      // Keep showing cached data if available; only surface error if nothing cached
      if (cached == null || cached.isEmpty) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<CalendarModel?> createCalendar(String name, {bool photoMode = false, int hueIndex = 0, String? icon}) async {
    try {
      final res = await _api.post('/calendars', data: {
        'name': name,
        if (photoMode) 'photo_mode': true,
        'hue_index': hueIndex,
        if (icon != null) 'icon': icon,
      });
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

  Future<void> updateCalendarAppearance(String calendarId, {int? hueIndex, String? icon, bool clearIcon = false}) async {
    // Optimistic local update
    if (hueIndex != null) setCalendarHue(calendarId, hueIndex);
    if (icon != null) setCalendarIcon(calendarId, icon);
    if (clearIcon) clearCalendarIconOverride(calendarId);
    state.whenData((list) {
      state = AsyncValue.data(list.map((c) {
        if (c.id != calendarId) return c;
        return c.copyWith(hueIndex: hueIndex, icon: icon, clearIcon: clearIcon);
      }).toList());
    });

    try {
      final body = <String, dynamic>{};
      if (hueIndex != null) body['hue_index'] = hueIndex;
      if (icon != null) body['icon'] = icon;
      if (clearIcon) body['icon'] = null;
      if (body.isNotEmpty) await _api.patch('/calendars/$calendarId', data: body);
    } catch (_) {}
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

  Future<bool> deleteCalendar(String calendarId) async {
    // Grab the calendar's local photo icon before deletion so we can clean it up
    CalendarModel? calendar;
    state.whenData((list) {
      try { calendar = list.firstWhere((c) => c.id == calendarId); } catch (_) {}
    });
    final iconUrl = calendar != null ? calendarIcon(calendar!) : null;
    final isPhotoIcon = iconUrl != null &&
        (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'));

    try {
      await _api.delete('/calendars/$calendarId');

      // Clear local icon cache entry
      await clearPersistedCalendarIcon(calendarId);

      // Ask backend to delete the Cloudinary photo icon (fire-and-forget)
      if (isPhotoIcon) _api.deleteAsset(iconUrl);

      state.whenData((list) {
        final updated = list.where((c) => c.id != calendarId).toList();
        state = AsyncValue.data(updated);
        _cache.saveCalendars(updated);
        _cache.clearEvents(calendarId);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leaveCalendar(String calendarId) async {
    try {
      await _api.post('/calendars/$calendarId/leave');
      state.whenData((list) {
        final updated = list.where((c) => c.id != calendarId).toList();
        state = AsyncValue.data(updated);
        _cache.saveCalendars(updated);
        _cache.clearEvents(calendarId);
      });
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
