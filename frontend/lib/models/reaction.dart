class EventReaction {
  final String emoji;
  final String userId;
  final String userName;
  final DateTime createdAt;

  const EventReaction({
    required this.emoji,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  factory EventReaction.fromJson(Map<String, dynamic> json) => EventReaction(
        emoji: json['emoji'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? 'Unknown',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
