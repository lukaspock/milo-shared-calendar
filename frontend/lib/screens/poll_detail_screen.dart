import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poll.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/polls_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';

class PollDetailScreen extends ConsumerStatefulWidget {
  final String calendarId;
  final String pollId;
  final Object? extra;

  const PollDetailScreen({
    super.key,
    required this.calendarId,
    required this.pollId,
    this.extra,
  });

  @override
  ConsumerState<PollDetailScreen> createState() => _PollDetailScreenState();
}

// Same reminder options as on the event form.
const _kPollReminderOptions = [null, 5, 15, 30, 60, 120, 1440];

String _pollReminderLabel(int? minutes) {
  if (minutes == null) return 'None';
  if (minutes < 60) return '$minutes min';
  if (minutes == 60) return '1 hour';
  if (minutes < 1440) return '${minutes ~/ 60} hours';
  return '1 day';
}

class _PollDetailScreenState extends ConsumerState<PollDetailScreen> {
  bool _isLoading = false;
  // Default reminder for the event that will be created when the poll is confirmed.
  int? _reminderMinutes = 30;

  EventPoll? get _poll {
    final polls = ref.watch(pollsProvider(widget.calendarId)).valueOrNull;
    return polls?.where((p) => p.id == widget.pollId).firstOrNull ??
        (widget.extra is EventPoll ? widget.extra as EventPoll : null);
  }

  String _fmtFull(DateTime dt) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${wd[dt.weekday - 1]}, ${mo[dt.month - 1]} ${dt.day}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _vote(String optionId, String vote) async {
    setState(() => _isLoading = true);
    final ok = await ref
        .read(pollsProvider(widget.calendarId).notifier)
        .vote(pollId: widget.pollId, optionId: optionId, vote: vote);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save vote. Try again.')),
      );
    }
  }

  Future<void> _confirm(String optionId) async {
    // Show confirmation dialog with reminder picker.
    final result = await showDialog<({bool confirmed, int? reminder})>(
      context: context,
      builder: (ctx) => _ConfirmPollDialog(initialReminder: _reminderMinutes),
    );
    if (result == null || !result.confirmed || !mounted) return;
    setState(() {
      _isLoading = true;
      _reminderMinutes = result.reminder;
    });
    final ok = await ref
        .read(pollsProvider(widget.calendarId).notifier)
        .confirmPoll(
          pollId: widget.pollId,
          optionId: optionId,
          reminderMinutes: result.reminder,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created and added to calendar.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create event. Try again.')),
      );
    }
  }

  Future<void> _suggestTime() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SuggestTimeSheet(
        calendarId: widget.calendarId,
        pollId: widget.pollId,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete poll'),
        content: const Text('Are you sure you want to delete this poll?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    final ok = await ref
        .read(pollsProvider(widget.calendarId).notifier)
        .deletePoll(widget.pollId);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) context.go('/calendar/${widget.calendarId}');
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    final currentUserId = ref.watch(authProvider).user?.id ?? '';
    final calendarsAsync = ref.watch(calendarProvider);
    final calendar = calendarsAsync.valueOrNull
        ?.where((c) => c.id == widget.calendarId)
        .firstOrNull;
    final calHue = calendar != null ? hueFor(calendar) : stickerHues[0];

    if (poll == null) {
      return Scaffold(
        backgroundColor: context.appColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/calendar/${widget.calendarId}'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: context.appColors.line,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: context.appColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.appColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isCreator = poll.createdBy == currentUserId;

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/calendar/${widget.calendarId}'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.appColors.line,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: context.appColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Poll',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.ink,
                      ),
                    ),
                  ),
                  if (isCreator && !_isLoading) ...[
                    GestureDetector(
                      onTap: _delete,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: context.appColors.line,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: AppImages.poll(size: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      poll.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.ink,
                        letterSpacing: -0.6,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Meta row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: poll.closed
                                ? const Color(0xFFD4EDDA)
                                : calHue.bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            poll.closed ? '✓ Confirmed' : '⚡ Open',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: poll.closed
                                  ? const Color(0xFF155724)
                                  : calHue.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'by ${poll.creatorName ?? 'Unknown'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: context.appColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${poll.totalVoters} vote${poll.totalVoters == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: context.appColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    if (poll.description != null &&
                        poll.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        poll.description!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: context.appColors.inkSoft,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Options
                    Text(
                      'TIME OPTIONS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.inkMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ...poll.options.map((opt) {
                      final myVote = opt.voteFor(currentUserId);
                      final isConfirmed = poll.confirmedOptionId == opt.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OptionCard(
                          option: opt,
                          voteOptions: poll.voteOptions,
                          myVote: myVote,
                          isConfirmed: isConfirmed,
                          pollClosed: poll.closed,
                          isCreator: isCreator,
                          isLoading: _isLoading,
                          fmtFull: _fmtFull,
                          onVote: (v) => _vote(opt.id, v),
                          onConfirm: () => _confirm(opt.id),
                          calHue: calHue,
                        ),
                      );
                    }),

                    if (!poll.closed) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _suggestTime,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: context.appColors.line,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: calHue.deep,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Suggest a time',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: calHue.deep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.voteOptions,
    required this.myVote,
    required this.isConfirmed,
    required this.pollClosed,
    required this.isCreator,
    required this.isLoading,
    required this.fmtFull,
    required this.onVote,
    required this.onConfirm,
    required this.calHue,
  });

  final PollOption option;
  final List<PollVoteOption> voteOptions;
  final String? myVote;
  final bool isConfirmed;
  final bool pollClosed;
  final bool isCreator;
  final bool isLoading;
  final String Function(DateTime) fmtFull;
  final void Function(String) onVote;
  final VoidCallback onConfirm;
  final CalHue calHue;

  bool get _hasCustomOptions => voteOptions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isConfirmed
            ? const Color(0xFFF0FFF4)
            : context.appColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfirmed ? const Color(0xFF28A745) : context.appColors.line,
          width: isConfirmed ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.appColors.line.withOpacity(0.5),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Time range
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                if (isConfirmed) ...[
                  const Text('✅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmtFull(option.startTime),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.ink,
                        ),
                      ),
                      Text(
                        '→ ${fmtFull(option.endTime)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: context.appColors.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConfirmed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28A745),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Confirmed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Vote counts
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _hasCustomOptions
                ? _CustomVoteCounts(
                    option: option,
                    voteOptions: voteOptions,
                    context: context,
                  )
                : Row(
                    children: [
                      _VoteCount(
                        label: '✅ ${option.yesCount}',
                        color: const Color(0xFF28A745),
                      ),
                      const SizedBox(width: 12),
                      _VoteCount(
                        label: '❓ ${option.maybeCount}',
                        color: const Color(0xFFC8951A),
                      ),
                      const SizedBox(width: 12),
                      _VoteCount(
                        label: '❌ ${option.noCount}',
                        color: const Color(0xFFDC3545),
                      ),
                      const Spacer(),
                      Text(
                        '${option.votes.length} vote${option.votes.length == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: context.appColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),

          // Vote chips (only when open)
          if (!pollClosed) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: context.appColors.line,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: _hasCustomOptions
                  ? _CustomVoteChips(
                      voteOptions: voteOptions,
                      myVote: myVote,
                      isLoading: isLoading,
                      onVote: onVote,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _VoteChip(
                            label: 'Yes',
                            emoji: '✅',
                            selected: myVote == 'yes',
                            bgColor: const Color(0xFFD4EDDA),
                            borderColor: const Color(0xFF28A745),
                            onTap: isLoading
                                ? null
                                : () => onVote(myVote == 'yes' ? 'no' : 'yes'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VoteChip(
                            label: 'Maybe',
                            emoji: '❓',
                            selected: myVote == 'maybe',
                            bgColor: const Color(0xFFFFF3CD),
                            borderColor: const Color(0xFFE5B130),
                            onTap: isLoading ? null : () => onVote('maybe'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VoteChip(
                            label: 'No',
                            emoji: '❌',
                            selected: myVote == 'no',
                            bgColor: const Color(0xFFF8D7DA),
                            borderColor: const Color(0xFFDC3545),
                            onTap: isLoading ? null : () => onVote('no'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],

          // Create Event button (creator only, poll open)
          if (!pollClosed && isCreator) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: context.appColors.line,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isLoading ? null : onConfirm,
                  style: TextButton.styleFrom(
                    backgroundColor: calHue.bg,
                    foregroundColor: calHue.ink,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: AppImages.target(size: 14),
                  label: Text(
                    'Create Event',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomVoteCounts extends StatelessWidget {
  const _CustomVoteCounts({
    required this.option,
    required this.voteOptions,
    required this.context,
  });

  final PollOption option;
  final List<PollVoteOption> voteOptions;
  final BuildContext context;

  @override
  Widget build(_) {
    return Row(
      children: [
        ...voteOptions.map((vo) {
          final count = option.countFor(vo.label);
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _VoteCount(
              label: '$count  ${vo.label}',
              color: vo.flutterColor,
            ),
          );
        }),
        const Spacer(),
        Text(
          '${option.votes.length} vote${option.votes.length == 1 ? '' : 's'}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: context.appColors.inkMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CustomVoteChips extends StatelessWidget {
  const _CustomVoteChips({
    required this.voteOptions,
    required this.myVote,
    required this.isLoading,
    required this.onVote,
  });

  final List<PollVoteOption> voteOptions;
  final String? myVote;
  final bool isLoading;
  final void Function(String) onVote;

  @override
  Widget build(BuildContext context) {
    // Wrap in case there are many options (3+)
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: voteOptions.map((vo) {
        final selected = myVote == vo.label;
        final color = vo.flutterColor;
        final bg = color.withOpacity(0.12);
        return GestureDetector(
          onTap: isLoading ? null : () => onVote(selected ? '' : vo.label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color : color.withOpacity(0.3),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              vo.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? color : color.withOpacity(0.7),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _VoteCount extends StatelessWidget {
  const _VoteCount({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? borderColor : borderColor.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '$emoji $label',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? borderColor : borderColor.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Suggest time bottom sheet ─────────────────────────────────────────────────

class _SuggestTimeSheet extends ConsumerStatefulWidget {
  const _SuggestTimeSheet({required this.calendarId, required this.pollId});
  final String calendarId;
  final String pollId;

  @override
  ConsumerState<_SuggestTimeSheet> createState() => _SuggestTimeSheetState();
}

class _SuggestTimeSheetState extends ConsumerState<_SuggestTimeSheet> {
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day + 1, 10, 0);
    _end = _start.add(const Duration(hours: 1));
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: ctx.appColors.ink,
            onPrimary: Colors.white,
            surface: ctx.appColors.surface,
            onSurface: ctx.appColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: ctx.appColors.ink,
            onPrimary: Colors.white,
            surface: ctx.appColors.surface,
            onSurface: ctx.appColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _start = dt;
        if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = dt;
      }
    });
  }

  Future<void> _submit() async {
    if (_end.isBefore(_start) || _end.isAtSameMomentAs(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(pollsProvider(widget.calendarId).notifier)
        .addOption(pollId: widget.pollId, start: _start, end: _end);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add option. Try again.')),
      );
    }
  }

  String _fmt(DateTime dt) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${wd[dt.weekday - 1]}, ${mo[dt.month - 1]} ${dt.day}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Suggest a time',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.ink,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: context.appColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'START',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: context.appColors.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickDateTime(isStart: true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appColors.line, width: 1.5),
              ),
              child: Text(
                _fmt(_start),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'END',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: context.appColors.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickDateTime(isStart: false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appColors.line, width: 1.5),
              ),
              child: Text(
                _fmt(_end),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Add suggestion',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm poll dialog with reminder picker ──────────────────────────────────

class _ConfirmPollDialog extends StatefulWidget {
  const _ConfirmPollDialog({required this.initialReminder});
  final int? initialReminder;

  @override
  State<_ConfirmPollDialog> createState() => _ConfirmPollDialogState();
}

class _ConfirmPollDialogState extends State<_ConfirmPollDialog> {
  late int? _reminder;

  @override
  void initState() {
    super.initState();
    _reminder = widget.initialReminder;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Create event?',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will close the poll and create a regular event for this time slot.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            'REMINDER',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kPollReminderOptions.map((opt) {
              final selected = opt == _reminder;
              return GestureDetector(
                onTap: () => setState(() => _reminder = opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _pollReminderLabel(opt),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, (confirmed: false, reminder: _reminder)),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, (confirmed: true, reminder: _reminder)),
          child: const Text('Create Event'),
        ),
      ],
    );
  }
}
