class RsvpUser {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String? color;

  const RsvpUser({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.color,
  });

  factory RsvpUser.fromJson(Map<String, dynamic> json) => RsvpUser(
        userId: json['user_id'] as String,
        userName: json['user_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        color: json['color'] as String?,
      );
}

class EventRsvpDetail {
  final List<RsvpUser> attending;
  final List<RsvpUser> notAttending;
  final List<RsvpUser> unsure;
  final String? myStatus;

  const EventRsvpDetail({
    required this.attending,
    required this.notAttending,
    required this.unsure,
    this.myStatus,
  });

  const EventRsvpDetail.empty()
      : attending = const [],
        notAttending = const [],
        unsure = const [],
        myStatus = null;

  factory EventRsvpDetail.fromJson(Map<String, dynamic> json) => EventRsvpDetail(
        attending: (json['attending'] as List<dynamic>)
            .map((e) => RsvpUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        notAttending: (json['not_attending'] as List<dynamic>)
            .map((e) => RsvpUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        unsure: (json['unsure'] as List<dynamic>)
            .map((e) => RsvpUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        myStatus: json['my_status'] as String?,
      );
}

class RsvpSummary {
  final int attendingCount;
  final int notAttendingCount;
  final int unsureCount;
  final String? myStatus;

  const RsvpSummary({
    required this.attendingCount,
    required this.notAttendingCount,
    required this.unsureCount,
    this.myStatus,
  });

  factory RsvpSummary.fromJson(Map<String, dynamic> json) => RsvpSummary(
        attendingCount: json['attending_count'] as int? ?? 0,
        notAttendingCount: json['not_attending_count'] as int? ?? 0,
        unsureCount: json['unsure_count'] as int? ?? 0,
        myStatus: json['my_status'] as String?,
      );
}
