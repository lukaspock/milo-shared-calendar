class CalendarModel {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final String role;
  final int memberCount;
  final DateTime createdAt;

  const CalendarModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.role,
    required this.memberCount,
    required this.createdAt,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) => CalendarModel(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String,
        inviteCode: json['invite_code'] as String,
        role: json['role'] as String? ?? 'member',
        memberCount: int.tryParse(json['member_count']?.toString() ?? '1') ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isOwner => role == 'owner';

  CalendarModel copyWithMemberCount(int count) => CalendarModel(
        id: id,
        name: name,
        ownerId: ownerId,
        inviteCode: inviteCode,
        role: role,
        memberCount: count,
        createdAt: createdAt,
      );
}
