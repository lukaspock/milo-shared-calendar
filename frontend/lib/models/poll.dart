import 'package:flutter/material.dart';

class PollOptionInput {
  final DateTime start;
  final DateTime end;
  const PollOptionInput({required this.start, required this.end});
}

class PollVoteOptionInput {
  String label;
  String color;
  PollVoteOptionInput({required this.label, required this.color});
}

class PollVoteOption {
  final String id;
  final String label;
  final String color;
  final int position;

  const PollVoteOption({
    required this.id,
    required this.label,
    required this.color,
    required this.position,
  });

  Color get flutterColor {
    final h = color.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  factory PollVoteOption.fromJson(Map<String, dynamic> json) => PollVoteOption(
        id: json['id'] as String,
        label: json['label'] as String,
        color: json['color'] as String? ?? '#6C63FF',
        position: json['position'] as int? ?? 0,
      );
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

  int countFor(String label) => votes.where((v) => v.vote == label).length;

  // Legacy helpers for polls without custom vote options
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
  final List<PollVoteOption> voteOptions;
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
    this.voteOptions = const [],
    required this.createdAt,
  });

  bool get hasCustomVoteOptions => voteOptions.isNotEmpty;

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
        voteOptions: (json['vote_options'] as List? ?? [])
            .map((o) => PollVoteOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
