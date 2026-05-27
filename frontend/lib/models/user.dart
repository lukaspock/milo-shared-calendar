class AppUser {
  final String id;
  final String email;
  final String name;
  final String color;
  final bool emailVerified;
  final bool hasGoogleCalendar;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.color,
    this.emailVerified = false,
    this.hasGoogleCalendar = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#6C63FF',
        emailVerified: json['email_verified'] as bool? ?? false,
        hasGoogleCalendar: json['has_google_calendar'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'color': color,
        'email_verified': emailVerified,
        'has_google_calendar': hasGoogleCalendar,
      };
}
