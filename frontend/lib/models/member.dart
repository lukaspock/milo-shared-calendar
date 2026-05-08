class CalendarMember {
  final String id;
  final String email;
  final String name;
  final String color;
  final String role;
  final DateTime joinedAt;

  const CalendarMember({
    required this.id,
    required this.email,
    required this.name,
    required this.color,
    required this.role,
    required this.joinedAt,
  });

  factory CalendarMember.fromJson(Map<String, dynamic> json) => CalendarMember(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        color: json['color'] as String,
        role: json['role'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );

  bool get isOwner => role == 'owner';
}
