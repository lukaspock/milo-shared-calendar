class ChatMessage {
  final String id;
  final String calendarId;
  final String userId;
  final String senderName;
  final String? senderAvatarUrl;
  final String senderColor;
  final String content;
  final bool isDeleted;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.calendarId,
    required this.userId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.senderColor,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    calendarId: json['calendar_id'] as String,
    userId: json['user_id'] as String,
    senderName: json['sender_name'] as String,
    senderAvatarUrl: json['sender_avatar_url'] as String?,
    senderColor: json['sender_color'] as String? ?? '#6C63FF',
    content: json['content'] as String? ?? '',
    isDeleted: json['is_deleted'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  ChatMessage copyWith({bool? isDeleted, String? content}) => ChatMessage(
    id: id,
    calendarId: calendarId,
    userId: userId,
    senderName: senderName,
    senderAvatarUrl: senderAvatarUrl,
    senderColor: senderColor,
    content: content ?? this.content,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt,
  );
}
