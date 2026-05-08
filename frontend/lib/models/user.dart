class AppUser {
  final String id;
  final String email;
  final String name;
  final String color;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.color,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#6C63FF',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'color': color,
      };
}
