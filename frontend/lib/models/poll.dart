class PollOptionInput {
  final DateTime start;
  final DateTime end;
  const PollOptionInput({required this.start, required this.end});
}

class PollVote {
  final String userId;
  final String userName;
  final String vote;

  const PollVote({
    required this.userId,
    required this.userName,
    required this.vote,
  });

  factory PollVote.fromJson(Map<String, dynamic> json) => PollVote(
        userId: json['user_id'] as String? ?? '',
        userName: json['user_name'] as String? ?? 'Unknown',
        vote: json['vote'] as String,
      );
}

class PollOption {
  final String id;
  final String pollId;
  final DateTime startTime;
  final DateTime endTime;
  final List<PollVote> votes;

  const PollOption({
    required this.id,
    required this.pollId,
    required this.startTime,
    required this.endTime,
    required this.votes,
  });

  int get yesCount => votes.where((v) => v.vote == 'yes').length;
  int get noCount => votes.where((v) => v.vote == 'no').length;
  int get maybeCount => votes.where((v) => v.vote == 'maybe').length;

  String? voteFor(String userId) {
    try {
      return votes.firstWhere((v) => v.userId == userId).vote;
    } catch (_) {
      return null;
    }
  }

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        id: json['id'] as String,
        pollId: json['poll_id'] as String? ?? '',
        startTime: DateTime.parse(json['start_time'] as String).toLocal(),
        endTime: DateTime.parse(json['end_time'] as String).toLocal(),
        votes: (json['votes'] as List? ?? [])
            .map((v) => PollVote.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class EventPoll {
  final String id;
  final String calendarId;
  final String createdBy;
  final String? creatorName;
  final String title;
  final String? description;
  final bool closed;
  final String? confirmedOptionId;
  final List<PollOption> options;
  final DateTime createdAt;

  const EventPoll({
    required this.id,
    required this.calendarId,
    required this.createdBy,
    this.creatorName,
    required this.title,
    this.description,
    required this.closed,
    this.confirmedOptionId,
    required this.options,
    required this.createdAt,
  });

  int get totalVoters {
    final seen = <String>{};
    for (final opt in options) {
      for (final v in opt.votes) {
        seen.add(v.userId);
      }
    }
    return seen.length;
  }

  factory EventPoll.fromJson(Map<String, dynamic> json) => EventPoll(
        id: json['id'] as String,
        calendarId: json['calendar_id'] as String,
        createdBy: json['created_by'] as String? ?? '',
        creatorName: json['creator_name'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        closed: json['closed'] as bool? ?? false,
        confirmedOptionId: json['confirmed_option_id'] as String?,
        options: (json['options'] as List? ?? [])
            .map((o) => PollOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
