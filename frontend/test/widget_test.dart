// SharedCal Flutter tests
//
// Run with: flutter test
// These tests are intentionally self-contained (no network, no database).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_cal/models/event.dart';

// ---------------------------------------------------------------------------
// CalendarEvent model — fromJson / toJson round-trip
// ---------------------------------------------------------------------------

void main() {
  group('RecurrenceRule', () {
    test('fromApi maps known strings', () {
      expect(RecurrenceRule.fromApi('daily'),   RecurrenceRule.daily);
      expect(RecurrenceRule.fromApi('weekly'),  RecurrenceRule.weekly);
      expect(RecurrenceRule.fromApi('monthly'), RecurrenceRule.monthly);
    });

    test('fromApi falls back to none for unknown values', () {
      expect(RecurrenceRule.fromApi(null),      RecurrenceRule.none);
      expect(RecurrenceRule.fromApi(''),        RecurrenceRule.none);
      expect(RecurrenceRule.fromApi('hourly'),  RecurrenceRule.none);
    });

    test('apiValue is null for none, string otherwise', () {
      expect(RecurrenceRule.none.apiValue,    isNull);
      expect(RecurrenceRule.daily.apiValue,   'daily');
      expect(RecurrenceRule.weekly.apiValue,  'weekly');
      expect(RecurrenceRule.monthly.apiValue, 'monthly');
    });

    test('labels are human-readable', () {
      expect(RecurrenceRule.none.label,    'Does not repeat');
      expect(RecurrenceRule.daily.label,   'Daily');
      expect(RecurrenceRule.weekly.label,  'Weekly');
      expect(RecurrenceRule.monthly.label, 'Monthly');
    });
  });

  group('CalendarEvent.fromJson', () {
    final baseJson = <String, dynamic>{
      'id': 'event-id-1',
      'calendar_id': 'cal-id-1',
      'created_by': 'user-id-1',
      'title': 'Team Standup',
      'description': 'Daily sync',
      'start_time': '2026-06-01T09:00:00.000Z',
      'end_time':   '2026-06-01T09:30:00.000Z',
      'color': '#43B89C',
      'creator_name': 'Alice',
      'creator_color': '#6C63FF',
      'created_at': '2026-05-01T08:00:00.000Z',
      'updated_at': '2026-05-01T08:00:00.000Z',
    };

    test('parses required fields correctly', () {
      final event = CalendarEvent.fromJson(baseJson);
      expect(event.id, 'event-id-1');
      expect(event.calendarId, 'cal-id-1');
      expect(event.title, 'Team Standup');
      expect(event.description, 'Daily sync');
    });

    test('defaults recurrenceRule to none when absent', () {
      final event = CalendarEvent.fromJson(baseJson);
      expect(event.recurrenceRule, RecurrenceRule.none);
      expect(event.isRecurring, isFalse);
    });

    test('parses recurrenceRule from json', () {
      final json = {...baseJson, 'recurrence_rule': 'weekly'};
      final event = CalendarEvent.fromJson(json);
      expect(event.recurrenceRule, RecurrenceRule.weekly);
      expect(event.isRecurring, isTrue);
    });

    test('parses recurrenceEnd as DateTime when present', () {
      final json = {...baseJson, 'recurrence_end': '2026-12-31'};
      final event = CalendarEvent.fromJson(json);
      expect(event.recurrenceEnd, isNotNull);
      expect(event.recurrenceEnd!.year, 2026);
      expect(event.recurrenceEnd!.month, 12);
      expect(event.recurrenceEnd!.day, 31);
    });

    test('recurrenceEnd is null when absent', () {
      final event = CalendarEvent.fromJson(baseJson);
      expect(event.recurrenceEnd, isNull);
    });

    test('falls back to #6C63FF for missing color', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('color');
      final event = CalendarEvent.fromJson(json);
      // #6C63FF → 0xFF6C63FF
      expect(event.color.toARGB32(), 0xFF6C63FF);
    });
  });

  group('CalendarEvent.copyWith', () {
    final base = CalendarEvent.fromJson({
      'id': 'e1', 'calendar_id': 'c1', 'created_by': 'u1',
      'title': 'Original',
      'start_time': '2026-06-01T10:00:00.000Z',
      'end_time':   '2026-06-01T11:00:00.000Z',
      'color': '#FF6584',
      'created_at': '2026-05-01T00:00:00.000Z',
      'updated_at': '2026-05-01T00:00:00.000Z',
    });

    test('copies unchanged fields', () {
      final copy = base.copyWith(title: 'Updated');
      expect(copy.id, base.id);
      expect(copy.calendarId, base.calendarId);
    });

    test('replaces only the specified field', () {
      final copy = base.copyWith(title: 'New title');
      expect(copy.title, 'New title');
    });

    test('copies recurrenceRule when not overridden', () {
      final recurring = base.copyWith(recurrenceRule: RecurrenceRule.monthly);
      final copy = recurring.copyWith(title: 'Changed');
      expect(copy.recurrenceRule, RecurrenceRule.monthly);
    });
  });
}
