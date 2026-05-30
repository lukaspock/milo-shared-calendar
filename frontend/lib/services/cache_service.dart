import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar.dart';
import '../models/event.dart';

/// Persists calendars and per-calendar events as JSON in SharedPreferences.
/// Lets the app render instantly on launch before the first network response.
class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  static const _calendarsKey = 'cache_v1_calendars';
  static String _eventsKey(String calendarId) => 'cache_v1_events_$calendarId';

  // ── Calendars ──────────────────────────────────────────────────────────────

  Future<List<CalendarModel>?> loadCalendars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_calendarsKey);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.map((e) => CalendarModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCalendars(List<CalendarModel> calendars) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_calendarsKey, jsonEncode(calendars.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> clearCalendars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_calendarsKey);
    } catch (_) {}
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<List<CalendarEvent>?> loadEvents(String calendarId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_eventsKey(calendarId));
      if (raw == null) return null;
      final list = jsonDecode(raw) as List;
      return list.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEvents(String calendarId, List<CalendarEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_eventsKey(calendarId), jsonEncode(events.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> clearEvents(String calendarId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey(calendarId));
    } catch (_) {}
  }

  /// Clears all cached data — call on logout so another user starts fresh.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cache_v1_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
