import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/event.dart' as sc;

/// Syncs SharedCal events to the native device calendar (iOS EventKit /
/// Android CalendarContract). All state is stored locally in SharedPreferences
/// — no backend involvement.
///
/// Architecture notes:
/// - Singleton, like AuthService.
/// - All operations are fire-and-forget from the events provider (errors are
///   swallowed so calendar failures never break the main app flow).
/// - Uses tz.UTC for TZDateTime so the epoch timestamp is always preserved
///   correctly; the Calendar app on each platform converts to local time.
class DeviceCalendarService {
  static final DeviceCalendarService _instance = DeviceCalendarService._();
  factory DeviceCalendarService() => _instance;
  DeviceCalendarService._();

  final _plugin = DeviceCalendarPlugin();

  static const _enabledKey = 'device_calendar_enabled';
  static const _calendarIdKey = 'device_calendar_id';
  // JSON-encoded Map<String, String>: sharedCalEventId → deviceEventId
  static const _eventMapKey = 'device_event_ids';

  // ── Status ────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  // ── Connect / disconnect ──────────────────────────────────────────────────

  /// Requests calendar permission and finds/creates the SharedCal calendar.
  /// Returns true on success.
  Future<bool> connect() async {
    // 1. Check / request permission
    var perm = await _plugin.hasPermissions();
    if (perm.data != true) {
      perm = await _plugin.requestPermissions();
    }
    if (perm.data != true) return false;

    // 2. Find or create dedicated calendar
    final calId = await _getOrCreateCalendar();
    if (calId == null) return false;

    // 3. Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_calendarIdKey, calId);
    return true;
  }

  /// Disables device calendar sync. Existing events on the device are kept.
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  /// Returns the platform calendar ID to write events into.
  ///
  /// Priority:
  ///   1. Previously saved ID (verified to still exist).
  ///   2. Create a new "SharedCal" calendar (works reliably on iOS).
  ///   3. Fall back to the first writable calendar on the device (Android).
  Future<String?> _getOrCreateCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_calendarIdKey);

    if (savedId != null) {
      final result = await _plugin.retrieveCalendars();
      final exists = result.data?.any((c) => c.id == savedId) ?? false;
      if (exists) return savedId;
    }

    // Try to create a dedicated calendar named "SharedCal"
    try {
      final result = await _plugin.createCalendar(
        'SharedCal',
        calendarColor: const Color(0xFF6C63FF),
        localAccountName: 'SharedCal',
      );
      if (result.isSuccess && result.data != null) {
        await prefs.setString(_calendarIdKey, result.data!);
        return result.data;
      }
    } catch (_) {
      // createCalendar is not available on all Android setups — fall through
    }

    // Fallback: use the first writable calendar (typical on Android)
    final calendarsResult = await _plugin.retrieveCalendars();
    final writable = calendarsResult.data
            ?.where((c) => !(c.isReadOnly ?? true))
            .toList() ??
        [];
    if (writable.isEmpty) return null;
    final id = writable.first.id!;
    await prefs.setString(_calendarIdKey, id);
    return id;
  }

  // ── Event ID map (SharedPreferences) ─────────────────────────────────────

  Future<Map<String, String>> _loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventMapKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventMapKey, jsonEncode(map));
  }

  // ── Sync operations ───────────────────────────────────────────────────────

  /// Creates or updates the event in the device calendar.
  /// Call this after a successful API create or update.
  Future<void> syncEvent(sc.CalendarEvent event) async {
    try {
      if (!await isEnabled()) return;
      final prefs = await SharedPreferences.getInstance();
      final calId = prefs.getString(_calendarIdKey);
      if (calId == null) return;

      final map = await _loadMap();
      final existingDeviceId = map[event.id];

      // Use UTC so the epoch timestamp is preserved; the Calendar app on the
      // device converts it to local display time automatically.
      final deviceEvent = Event(
        calId,
        eventId: existingDeviceId,
        title: event.title,
        description: event.description,
        start: tz.TZDateTime.from(event.startTime, tz.UTC),
        end: tz.TZDateTime.from(event.endTime, tz.UTC),
      );

      final result = await _plugin.createOrUpdateEvent(deviceEvent);
      if (result?.isSuccess == true && result?.data != null) {
        map[event.id] = result!.data!;
        await _saveMap(map);
      }
    } catch (_) {
      // Never let calendar errors bubble up to the UI
    }
  }

  /// Reads events from all personal device calendars (not the SharedCal-managed one)
  /// and returns them as in-memory CalendarEvent objects with source=deviceImport.
  ///
  /// Returns [] on macOS (device_calendar package is iOS/Android only), or when
  /// device calendar sync is not enabled, or on any error.
  Future<List<sc.CalendarEvent>> readExternalEvents({
    required String sharedCalendarId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Guard: device_calendar only supports iOS and Android
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return [];
    }

    try {
      if (!await isEnabled()) return [];

      // Values in this map are device event IDs written by SharedCal — skip those events.
      // We no longer skip entire calendars by calId because the fallback path in connect()
      // may have stored the user's default iCloud calendar as calId, which would hide all
      // personal events. Filtering per-event by device ID is precise enough.
      final map = await _loadMap();
      final sharedCalDeviceIds = map.values.toSet();

      final calendarsResult = await _plugin.retrieveCalendars();
      final calendars = calendarsResult.data ?? [];

      final results = <sc.CalendarEvent>[];
      // Dedup key: title + UTC date — prevents the same holiday from appearing
      // twice when it exists in multiple iOS calendar sources (e.g. a subscribed
      // Austrian holidays calendar AND the iCloud calendar both carry Fronleichnam).
      final seenKeys = <String>{};

      for (final cal in calendars) {
        final eventsResult = await _plugin.retrieveEvents(
          cal.id!,
          RetrieveEventsParams(
            startDate: tz.TZDateTime.from(startDate, tz.UTC),
            endDate: tz.TZDateTime.from(endDate, tz.UTC),
          ),
        );

        for (final e in eventsResult.data ?? []) {
          if (e.status == EventStatus.Canceled) continue;
          if (e.eventId == null) continue;
          if (sharedCalDeviceIds.contains(e.eventId)) continue;
          if (e.title == null || e.start == null || e.end == null) continue;

          // Use TZDateTime's own year/month/day (device-local timezone) for the
          // dedup key — toUtc() would give the previous day for all-day events
          // in UTC+2 (midnight local = 22:00 UTC previous day).
          final dedupKey = '${e.title}|${e.start!.year}-${e.start!.month}-${e.start!.day}';
          if (seenKeys.contains(dedupKey)) continue;
          seenKeys.add(dedupKey);

          results.add(_toCalendarEvent(e, sharedCalendarId));
        }
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  sc.CalendarEvent _toCalendarEvent(Event e, String sharedCalendarId) {
    // All-day events on iOS are stored as midnight in the device's local
    // timezone. Using .toLocal() on the TZDateTime produces the correct UTC
    // instant but some plugin versions return the time in an unexpected zone,
    // causing a -2 h shift (e.g. Jun 14 00:00 CEST → Jun 13 22:00 displayed).
    // For all-day events we normalise directly from the TZDateTime's own
    // year/month/day fields (which are already in device-local time).
    final DateTime startTime;
    final DateTime endTime;
    if (e.allDay == true) {
      startTime = DateTime(e.start!.year, e.start!.month, e.start!.day);
      final rawEnd = DateTime(e.end!.year, e.end!.month, e.end!.day);
      // iOS end is midnight of the *next* day (exclusive) — step back 1 s
      endTime = rawEnd.isAfter(startTime)
          ? rawEnd.subtract(const Duration(seconds: 1))
          : startTime.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else {
      startTime = e.start!.toLocal();
      endTime = e.end!.toLocal();
    }

    return sc.CalendarEvent(
      id: 'device_${e.eventId}',
      calendarId: sharedCalendarId,
      createdBy: '',
      title: e.title ?? '',
      description: e.description,
      startTime: startTime,
      endTime: endTime,
      color: const Color(0xFF6C63FF),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      source: sc.EventSource.deviceImport,
      importedBy: const [],
    );
  }

  /// Deletes the matching event from the device calendar.
  /// Call this after a successful API delete.
  Future<void> deleteDeviceEvent(String sharedCalEventId) async {
    try {
      if (!await isEnabled()) return;
      final prefs = await SharedPreferences.getInstance();
      final calId = prefs.getString(_calendarIdKey);
      if (calId == null) return;

      final map = await _loadMap();
      final deviceEventId = map[sharedCalEventId];
      if (deviceEventId == null) return;

      await _plugin.deleteEvent(calId, deviceEventId);
      map.remove(sharedCalEventId);
      await _saveMap(map);
    } catch (_) {
      // Never let calendar errors bubble up to the UI
    }
  }
}
