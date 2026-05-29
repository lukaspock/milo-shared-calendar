/// How a user wants to be notified when a new event is created in one of
/// their calendars.
enum NotificationType {
  /// Email notification (sent by the backend).
  email,

  /// On-device local notification (shown by the app via flutter_local_notifications).
  push;

  String get apiValue => this == NotificationType.push ? 'push' : 'email';

  static NotificationType fromApi(String? value) =>
      value == 'push' ? NotificationType.push : NotificationType.email;
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final String color;
  final bool emailVerified;
  final bool hasGoogleCalendar;
  final NotificationType notificationType;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.color,
    this.emailVerified = false,
    this.hasGoogleCalendar = false,
    this.notificationType = NotificationType.email,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? color,
    bool? emailVerified,
    bool? hasGoogleCalendar,
    NotificationType? notificationType,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        color: color ?? this.color,
        emailVerified: emailVerified ?? this.emailVerified,
        hasGoogleCalendar: hasGoogleCalendar ?? this.hasGoogleCalendar,
        notificationType: notificationType ?? this.notificationType,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#6C63FF',
        emailVerified: json['email_verified'] as bool? ?? false,
        hasGoogleCalendar: json['has_google_calendar'] as bool? ?? false,
        notificationType:
            NotificationType.fromApi(json['notification_type'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'color': color,
        'email_verified': emailVerified,
        'has_google_calendar': hasGoogleCalendar,
        'notification_type': notificationType.apiValue,
      };
}
