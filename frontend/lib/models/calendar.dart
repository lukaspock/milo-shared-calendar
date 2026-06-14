class CalendarModel {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final String role;
  final int memberCount;
  final DateTime createdAt;
  final bool photoMode;
  final int hueIndex;
  final String? icon;

  const CalendarModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.role,
    required this.memberCount,
    required this.createdAt,
    this.photoMode = false,
    this.hueIndex = 0,
    this.icon,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) => CalendarModel(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['owner_id'] as String,
    inviteCode: json['invite_code'] as String,
    role: json['role'] as String? ?? 'member',
    memberCount: int.tryParse(json['member_count']?.toString() ?? '1') ?? 1,
    createdAt: DateTime.parse(json['created_at'] as String),
    photoMode: json['photo_mode'] as bool? ?? false,
    hueIndex: (json['hue_index'] as int?) ?? 0,
    icon: json['icon'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'owner_id': ownerId,
    'invite_code': inviteCode,
    'role': role,
    'member_count': memberCount,
    'created_at': createdAt.toIso8601String(),
    'photo_mode': photoMode,
    'hue_index': hueIndex,
    if (icon != null) 'icon': icon,
  };

  bool get isOwner => role == 'owner';

  CalendarModel copyWith({
    int? memberCount,
    int? hueIndex,
    String? icon,
    bool clearIcon = false,
  }) => CalendarModel(
    id: id,
    name: name,
    ownerId: ownerId,
    inviteCode: inviteCode,
    role: role,
    memberCount: memberCount ?? this.memberCount,
    createdAt: createdAt,
    photoMode: photoMode,
    hueIndex: hueIndex ?? this.hueIndex,
    icon: clearIcon ? null : (icon ?? this.icon),
  );

  CalendarModel copyWithMemberCount(int count) => copyWith(memberCount: count);
}
