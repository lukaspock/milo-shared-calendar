import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poll.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/polls_provider.dart';
import '../theme/app_theme.dart';

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

class _PollDetailScreenState extends ConsumerState<PollDetailScreen> {
  bool _isLoading = false;

  EventPoll? get _poll {
    final polls =
        ref.watch(pollsProvider(widget.calendarId)).valueOrNull;
    return polls?.where((p) => p.id == widget.pollId).firstOrNull ??
        (widget.extra is EventPoll ? widget.extra as EventPoll : null);
  }

  String _fmtFull(DateTime dt) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${wd[dt.weekday - 1]}, ${mo[dt.month - 1]} ${dt.day}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _vote(String optionId, String vote) async {
    setState(() => _isLoading = true);
    final ok = await ref.read(pollsProvider(widget.calendarId).notifier).vote(
          pollId: widget.pollId,
          optionId: optionId,
          vote: vote,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save vote. Try again.')),
      );
    }
  }

  Future<void> _confirm(String optionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm this slot?'),
        content: const Text(
            'This will close the poll and create a regular event for this time slot.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoading = true);
    final ok = await ref
        .read(pollsProvider(widget.calendarId).notifier)
        .confirmPoll(pollId: widget.pollId, optionId: optionId);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Poll confirmed! Event added to calendar.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm. Try again.')),
      );
    }
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
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
    final currentUserId =
        ref.watch(authProvider).user?.id ?? '';
    final calendarsAsync = ref.watch(calendarProvider);
    final calendar = calendarsAsync.valueOrNull
        ?.where((c) => c.id == widget.calendarId)
        .firstOrNull;
    final calHue = calendar != null ? hueFor(calendar) : stickerHues[0];

    if (poll == null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          context.go('/calendar/${widget.calendarId}'),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.line, width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: AppTheme.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.ink),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isCreator = poll.createdBy == currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        context.go('/calendar/${widget.calendarId}'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: AppTheme.line, width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppTheme.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Poll',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
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
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.line, width: 1.5),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppTheme.danger),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: const Text('📊',
                        style: TextStyle(fontSize: 18)),
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
                        color: AppTheme.ink,
                        letterSpacing: -0.6,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Meta row
                    Row(
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
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
                            color: AppTheme.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${poll.totalVoters} vote${poll.totalVoters == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.inkMuted,
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
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Options
                    Text(
                      'Time options',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.inkMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ...poll.options.map((opt) {
                      final myVote = opt.voteFor(currentUserId);
                      final isConfirmed =
                          poll.confirmedOptionId == opt.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OptionCard(
                          option: opt,
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
  final String? myVote;
  final bool isConfirmed;
  final bool pollClosed;
  final bool isCreator;
  final bool isLoading;
  final String Function(DateTime) fmtFull;
  final void Function(String) onVote;
  final VoidCallback onConfirm;
  final CalHue calHue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isConfirmed
            ? const Color(0xFFF0FFF4)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfirmed
              ? const Color(0xFF28A745)
              : AppTheme.line,
          width: isConfirmed ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.line.withOpacity(0.5),
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
                          color: AppTheme.ink,
                        ),
                      ),
                      Text(
                        '→ ${fmtFull(option.endTime)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConfirmed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
            child: Row(
              children: [
                _VoteCount(
                    label: '✅ ${option.yesCount}',
                    color: const Color(0xFF28A745)),
                const SizedBox(width: 12),
                _VoteCount(
                    label: '❓ ${option.maybeCount}',
                    color: const Color(0xFFC8951A)),
                const SizedBox(width: 12),
                _VoteCount(
                    label: '❌ ${option.noCount}',
                    color: const Color(0xFFDC3545)),
                const Spacer(),
                Text(
                  '${option.votes.length} vote${option.votes.length == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.inkMuted,
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
                color: AppTheme.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
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
                          : () => onVote(
                              myVote == 'yes' ? 'no' : 'yes'),
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
                      onTap: isLoading
                          ? null
                          : () => onVote('maybe'),
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
                      onTap: isLoading
                          ? null
                          : () => onVote('no'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Confirm button (creator only, poll open)
          if (!pollClosed && isCreator) ...[
            Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppTheme.line),
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
                  icon: const Text('🎯',
                      style: TextStyle(fontSize: 14)),
                  label: Text(
                    'Confirm this slot',
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
        padding:
            const EdgeInsets.symmetric(vertical: 8),
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
              fontWeight:
                  selected ? FontWeight.w800 : FontWeight.w500,
              color: selected
                  ? borderColor
                  : borderColor.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
