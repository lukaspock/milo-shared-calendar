class EventPhoto {
  final String id;
  final String eventId;
  final String calendarId;
  final String? uploadedBy;
  final String? uploadedByName;
  final String photoUrl;
  final DateTime createdAt;
  final String? eventTitle;
  final DateTime? eventStartTime;

  const EventPhoto({
    required this.id,
    required this.eventId,
    required this.calendarId,
    this.uploadedBy,
    this.uploadedByName,
    required this.photoUrl,
    required this.createdAt,
    this.eventTitle,
    this.eventStartTime,
  });

  factory EventPhoto.fromJson(Map<String, dynamic> json) => EventPhoto(
    id: json['id'] as String,
    eventId: json['event_id'] as String,
    calendarId: json['calendar_id'] as String,
    uploadedBy: json['uploaded_by'] as String?,
    uploadedByName: json['uploaded_by_name'] as String?,
    photoUrl: json['photo_url'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    eventTitle: json['event_title'] as String?,
    eventStartTime: json['event_start_time'] != null
        ? DateTime.parse(json['event_start_time'] as String).toLocal()
        : null,
  );
}
