import 'package:flutter/material.dart';

enum EventSource { sharedcal, googleImport, deviceImport }

class ImportedByUser {
  final String userId;
  final String name;
  final String color;

  const ImportedByUser({
    required this.userId,
    required this.name,
    required this.color,
  });

  factory ImportedByUser.fromJson(Map<String, dynamic> json) => ImportedByUser(
    userId: json['user_id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'color': color,
  };
}

enum RecurrenceRule {
  none,
  daily,
  weekly,
  monthly;

  String get label => switch (this) {
    RecurrenceRule.none => 'Does not repeat',
    RecurrenceRule.daily => 'Daily',
    RecurrenceRule.weekly => 'Weekly',
    RecurrenceRule.monthly => 'Monthly',
  };
  String? get apiValue => this == RecurrenceRule.none ? null : name;
  static RecurrenceRule fromApi(String? v) => switch (v) {
    'daily' => RecurrenceRule.daily,
    'weekly' => RecurrenceRule.weekly,
    'monthly' => RecurrenceRule.monthly,
    _ => RecurrenceRule.none,
  };
}

class CalendarEvent {
  final String id;
  final String calendarId;
  final String createdBy;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final Color color;
  final String? creatorName;
  final String? creatorColor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RecurrenceRule recurrenceRule;
  final DateTime? recurrenceEnd;

  /// Non-null for instances generated from a recurring root event.
  final String? parentEventId;

  /// Optional emoji or short label chosen by the creator (e.g. "🎂", "✈️").
  final String? icon;

  /// Where this event came from: SharedCal, a member's Google Calendar, or device calendar.
  final EventSource source;

  /// For googleImport events: which members' Google Calendars contributed this event.
  final List<ImportedByUser> importedBy;

  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.creatorName,
    this.creatorColor,
    required this.createdAt,
    required this.updatedAt,
    this.recurrenceRule = RecurrenceRule.none,
    this.recurrenceEnd,
    this.parentEventId,
    this.icon,
    this.source = EventSource.sharedcal,
    this.importedBy = const [],
  });

  bool get isRecurring => recurrenceRule != RecurrenceRule.none;
  bool get isRecurringInstance => parentEventId != null;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final colorHex = json['color'] as String? ?? '#6C63FF';
    final recEndRaw = json['recurrence_end'] as String?;
    final sourceRaw = json['source'] as String?;
    return CalendarEvent(
      id: json['id'] as String,
      calendarId: json['calendar_id'] as String,
      createdBy: json['created_by'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      color: _hexToColor(colorHex),
      creatorName: json['creator_name'] as String?,
      creatorColor: json['creator_color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      recurrenceRule: RecurrenceRule.fromApi(
        json['recurrence_rule'] as String?,
      ),
      recurrenceEnd: recEndRaw != null ? DateTime.parse(recEndRaw) : null,
      parentEventId: json['parent_event_id'] as String?,
      icon: json['icon'] as String?,
      source: sourceRaw == 'google_import'
          ? EventSource.googleImport
          : sourceRaw == 'device_import'
          ? EventSource.deviceImport
          : EventSource.sharedcal,
      importedBy: json['imported_by'] is List
          ? (json['imported_by'] as List<dynamic>)
                .map((e) => ImportedByUser.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'calendar_id': calendarId,
    'created_by': createdBy,
    'title': title,
    if (description != null) 'description': description,
    'start_time': startTime.toUtc().toIso8601String(),
    'end_time': endTime.toUtc().toIso8601String(),
    'color': '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
    if (creatorName != null) 'creator_name': creatorName,
    if (creatorColor != null) 'creator_color': creatorColor,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'source': source == EventSource.googleImport
        ? 'google_import'
        : source == EventSource.deviceImport
        ? 'device_import'
        : 'sharedcal',
    'imported_by': importedBy.map((u) => u.toJson()).toList(),
  };

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    Color? color,
    String? icon,
    RecurrenceRule? recurrenceRule,
    DateTime? recurrenceEnd,
    String? creatorColor,
    String? createdBy,
    List<ImportedByUser>? importedBy,
  }) {
    return CalendarEvent(
      id: id,
      calendarId: calendarId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      creatorName: creatorName,
      creatorColor: creatorColor ?? this.creatorColor,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceEnd: recurrenceEnd ?? this.recurrenceEnd,
      parentEventId: parentEventId,
      source: source,
      importedBy: importedBy ?? this.importedBy,
    );
  }
}
