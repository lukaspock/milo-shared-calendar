import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/poll.dart';
import '../providers/calendar_provider.dart';
import '../providers/events_provider.dart';
import '../providers/polls_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/members_dialog.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  final String calendarId;
  const CalendarScreen({super.key, required this.calendarId});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreateChoiceSheet(
        calendarId: widget.calendarId,
        selectedDay: _selectedDay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider(widget.calendarId));
    final polls = ref.watch(pollsProvider(widget.calendarId)).valueOrNull ?? [];
    final openPolls = polls.where((p) => !p.closed).toList();

    final calendarsAsync = ref.watch(calendarProvider);
    final calendar = calendarsAsync.valueOrNull
        ?.where((c) => c.id == widget.calendarId)
        .firstOrNull;
    final calHue = calendar != null ? hueFor(calendar) : stickerHues[0];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.line, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calendar?.name ?? 'Calendar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (calendar != null)
                          Text(
                            '${calendar.memberCount} member${calendar.memberCount == 1 ? '' : 's'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppTheme.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (calendar != null)
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => MembersSheet(calendar: calendar),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.line, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.people_rounded,
                          size: 18,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ref
                        .read(eventsProvider(widget.calendarId).notifier)
                        .fetch(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.line, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: eventsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.ink),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: AppTheme.inkSoft),
                  ),
                ),
                data: (events) {
                  final eventsByDay = <DateTime, List<CalendarEvent>>{};
                  for (final e in events) {
                    final key = DateTime(
                      e.startTime.year,
                      e.startTime.month,
                      e.startTime.day,
                    );
                    eventsByDay.putIfAbsent(key, () => []).add(e);
                  }

                  final selKey = _selectedDay == null
                      ? null
                      : DateTime(
                          _selectedDay!.year,
                          _selectedDay!.month,
                          _selectedDay!.day,
                        );
                  final selectedEvents = selKey == null
                      ? <CalendarEvent>[]
                      : (eventsByDay[selKey] ?? []);

                  return Column(
                    children: [
                      // ── Calendar card ──────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.line,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.line.withOpacity(0.5),
                                offset: const Offset(0, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: _CalendarGrid(
                            month: _focusedMonth,
                            selectedDay: _selectedDay,
                            eventsByDay: eventsByDay,
                            calHue: calHue,
                            onMonthChanged: (m) =>
                                setState(() => _focusedMonth = m),
                            onDaySelected: (d) =>
                                setState(() => _selectedDay = d),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(child: const SizedBox(height: 16)),

                      // ── Day header ─────────────────────────────────────
                      if (_selectedDay != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                DateFormat(
                                  'EEE, MMM d',
                                ).format(_selectedDay!).toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.inkMuted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isSameDay(_selectedDay!, DateTime.now()))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: calHue.bg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'today',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: calHue.ink,
                                    ),
                                  ),
                                ),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      Expanded(
                        child: selectedEvents.isEmpty
                            ? Center(
                                child: Text(
                                  _selectedDay == null
                                      ? 'Tap a date to see events'
                                      : 'No events on this day',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.inkMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                itemCount: selectedEvents.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final ev = selectedEvents[i];
                                  return _EventRow(
                                    event: ev,
                                    calHue: calHue,
                                    onTap: () => context.go(
                                      '/calendar/${widget.calendarId}/event/${ev.id}',
                                      extra: ev,
                                    ),
                                    fmtTime: _fmt,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x551F1B16),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _showCreateSheet,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            '+ Add event',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Create-choice bottom sheet ────────────────────────────────────────────────

class _CreateChoiceSheet extends StatelessWidget {
  const _CreateChoiceSheet({
    required this.calendarId,
    required this.selectedDay,
  });
  final String calendarId;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.line, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.line.withOpacity(0.5),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'What do you want to create?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: AppTheme.line,
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            emoji: '📅',
            title: 'Regular event',
            subtitle: 'Fixed date and time slot',
            onTap: () {
              Navigator.pop(context);
              context.go('/calendar/$calendarId/event/new', extra: selectedDay);
            },
          ),
          _ChoiceTile(
            emoji: '📊',
            title: 'Poll',
            subtitle: 'Let the group vote on a time',
            onTap: () {
              Navigator.pop(context);
              context.go('/calendar/$calendarId/polls/new');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Poll card (in list) ───────────────────────────────────────────────────────

class _PollCard extends StatefulWidget {
  const _PollCard({
    required this.poll,
    required this.calHue,
    required this.onTap,
  });
  final EventPoll poll;
  final CalHue calHue;
  final VoidCallback onTap;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hue = widget.calHue;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.line.withOpacity(0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 52,
              decoration: BoxDecoration(
                color: hue.bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: hue.deep.withOpacity(0.13),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.poll.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hue.dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.poll.options.length} option${widget.poll.options.length == 1 ? '' : 's'}'
                        ' · ${widget.poll.totalVoters} vote${widget.poll.totalVoters == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.inkMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom calendar grid ──────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.eventsByDay,
    required this.calHue,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final Map<DateTime, List<CalendarEvent>> eventsByDay;
  final CalHue calHue;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final today = DateTime.now();

    return Column(
      children: [
        // Month nav
        Row(
          children: [
            GestureDetector(
              onTap: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1)),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.line),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: AppTheme.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () =>
                  onMonthChanged(DateTime(month.year, month.month + 1)),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.line),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.inkMuted,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: _weekdays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        const SizedBox(height: 6),

        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            mainAxisExtent: 58,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (_, index) {
            if (index < startOffset) return const SizedBox.shrink();
            final day = index - startOffset + 1;
            final date = DateTime(month.year, month.month, day);
            final key = DateTime(date.year, date.month, date.day);
            final dayEvents = eventsByDay[key] ?? [];
            final isSelected =
                selectedDay != null && _isSameDay(date, selectedDay!);
            final isToday = _isSameDay(date, today);

            return GestureDetector(
              onTap: () => onDaySelected(date),
              child: _DayCell(
                day: day,
                events: dayEvents,
                calHue: calHue,
                isSelected: isSelected,
                isToday: isToday,
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.calHue,
    required this.isSelected,
    required this.isToday,
  });

  final int day;
  final List<CalendarEvent> events;
  final CalHue calHue;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: isSelected ? calHue.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: calHue.deep.withOpacity(0.13),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 6),
          Text(
            '$day',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isSelected
                  ? calHue.ink
                  : isToday
                  ? calHue.deep
                  : AppTheme.ink,
            ),
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? calHue.dot.withOpacity(0.25) : calHue.bg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  events.length > 1 ? '+${events.length}' : events[0].title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    color: calHue.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Event row ─────────────────────────────────────────────────────────────────

class _EventRow extends StatefulWidget {
  const _EventRow({
    required this.event,
    required this.calHue,
    required this.onTap,
    required this.fmtTime,
  });

  final CalendarEvent event;
  final CalHue calHue;
  final VoidCallback onTap;
  final String Function(DateTime) fmtTime;

  @override
  State<_EventRow> createState() => _EventRowState();
}

class _EventRowState extends State<_EventRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hue = widget.calHue;
    final start = widget.event.startTime;
    final months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.line.withOpacity(0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 52,
              decoration: BoxDecoration(
                color: hue.bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: hue.deep.withOpacity(0.13),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    months[start.month - 1],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: hue.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${start.day}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: hue.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hue.dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.fmtTime(widget.event.startTime)} – ${widget.fmtTime(widget.event.endTime)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.inkMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
