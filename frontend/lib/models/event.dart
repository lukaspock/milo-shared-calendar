import 'package:flutter/material.dart';

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
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final colorHex = json['color'] as String? ?? '#6C63FF';
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
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    Color? color,
  }) {
    return CalendarEvent(
      id: id,
      calendarId: calendarId,
      createdBy: createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      creatorName: creatorName,
      creatorColor: creatorColor,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
