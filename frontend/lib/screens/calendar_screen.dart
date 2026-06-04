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
import '../widgets/app_image.dart';
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
      backgroundColor: context.appColors.bg,
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
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appColors.line, width: 1.5),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: context.appColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: context.appColors.inkMuted,
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
                            color: context.appColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (calendar != null)
                          Text(
                            '${calendar.memberCount} member${calendar.memberCount == 1 ? '' : 's'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: context.appColors.inkMuted,
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
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.appColors.line, width: 1.5),
                        ),
                        child: Icon(
                          Icons.people_rounded,
                          size: 18,
                          color: context.appColors.ink,
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
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appColors.line, width: 1.5),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: context.appColors.ink,
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
                loading: () => Center(
                  child: CircularProgressIndicator(color: context.appColors.ink),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: context.appColors.inkSoft),
                  ),
                ),
                data: (events) {
                  final eventsByDay = <DateTime, List<CalendarEvent>>{};
                  for (final e in events) {
                    final startDate = DateTime(
                      e.startTime.year,
                      e.startTime.month,
                      e.startTime.day,
                    );
                    final endDate = DateTime(
                      e.endTime.year,
                      e.endTime.month,
                      e.endTime.day,
                    );
                    var current = startDate;
                    while (!current.isAfter(endDate)) {
                      eventsByDay.putIfAbsent(current, () => []).add(e);
                      current = current.add(const Duration(days: 1));
                    }
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
                            color: context.appColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: context.appColors.line,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.appColors.line.withOpacity(0.5),
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

                      const SizedBox(height: 16),

                      // ── Day header ─────────────────────────────────────
                      if (_selectedDay != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                DateFormat('EEE, MMM d')
                                    .format(_selectedDay!)
                                    .toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: context.appColors.inkMuted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isSameDay(_selectedDay!, DateTime.now()))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
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

                      // ── Events + Polls ─────────────────────────────────
                      Expanded(
                        child: ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          children: [
                            // Events for selected day
                            if (selectedEvents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                child: Text(
                                  _selectedDay == null
                                      ? 'Tap a date to see events'
                                      : 'No events on this day',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: context.appColors.inkMuted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else
                              ...selectedEvents.asMap().entries.map((e) {
                                final ev = e.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                      bottom: e.key <
                                              selectedEvents.length - 1
                                          ? 10
                                          : 0),
                                  child: _EventRow(
                                    event: ev,
                                    calHue: calHue,
                                    onTap: () => context.go(
                                      '/calendar/${widget.calendarId}/event/${ev.id}',
                                      extra: ev,
                                    ),
                                    fmtTime: _fmt,
                                  ),
                                );
                              }),

                            // ── Polls section ─────────────────────────────
                            if (openPolls.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Text(
                                    'OPEN POLLS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: context.appColors.inkMuted,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: calHue.bg,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${openPolls.length}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: calHue.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...openPolls.asMap().entries.map((e) {
                                final poll = e.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          e.key < openPolls.length - 1
                                              ? 10
                                              : 0),
                                  child: _PollCard(
                                    poll: poll,
                                    calHue: calHue,
                                    onTap: () => context.go(
                                      '/calendar/${widget.calendarId}/polls/${poll.id}',
                                      extra: poll,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
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
          boxShadow: [
            BoxShadow(
              color: context.appColors.ink.withOpacity(0.33),
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
            '+ Add',
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.appColors.line, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.appColors.line.withOpacity(0.5),
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
                color: context.appColors.ink,
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: context.appColors.line,
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: AppImages.calendar(size: 28),
            title: 'Regular event',
            subtitle: 'Fixed date and time slot',
            onTap: () {
              Navigator.pop(context);
              context.go('/calendar/$calendarId/event/new', extra: selectedDay);
            },
          ),
          _ChoiceTile(
            icon: AppImages.poll(size: 28),
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Widget icon;
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
            color: context.appColors.surfaceSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              icon,
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
                        color: context.appColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: context.appColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.appColors.inkMuted,
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
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: context.appColors.line.withOpacity(0.5),
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
              child: Center(
                child: AppImages.poll(size: 20),
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
                      color: context.appColors.ink,
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
                          color: context.appColors.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appColors.inkMuted,
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
                  color: context.appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appColors.line),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: context.appColors.inkMuted,
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
                    color: context.appColors.ink,
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
                  color: context.appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appColors.line),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.appColors.inkMuted,
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
                        color: context.appColors.inkMuted,
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
                  : context.appColors.ink,
            ),
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _DayCellBadge(
                events: events,
                calHue: calHue,
                isSelected: isSelected,
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
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: context.appColors.line.withOpacity(0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            _EventRowIcon(event: widget.event, hue: hue),
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
                      color: context.appColors.ink,
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
                          color: context.appColors.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appColors.inkMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

bool _isIconUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

// Badge shown inside a day cell — icon or title for 1 event, count for many.
class _DayCellBadge extends StatelessWidget {
  const _DayCellBadge({
    required this.events,
    required this.calHue,
    required this.isSelected,
  });
  final List<CalendarEvent> events;
  final CalHue calHue;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? calHue.dot.withOpacity(0.25) : calHue.bg;
    final single = events.length == 1;
    final icon = single ? events[0].icon : null;

    if (single && icon != null && _isIconUrl(icon)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: double.infinity,
          height: 18,
          child: Image.network(
            icon,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _textBadge(events[0].title, bg),
          ),
        ),
      );
    }

    if (single && icon != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 11, height: 1.3)),
      );
    }

    return _textBadge(single ? events[0].title : '+${events.length}', bg);
  }

  Widget _textBadge(String text, Color bg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 8,
            color: calHue.ink,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      );
}

// Left-side icon box for an event row — event icon when set, date otherwise.
class _EventRowIcon extends StatelessWidget {
  const _EventRowIcon({required this.event, required this.hue});
  final CalendarEvent event;
  final CalHue hue;

  @override
  Widget build(BuildContext context) {
    final icon = event.icon;
    final decoration = BoxDecoration(
      color: hue.bg,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: hue.deep.withOpacity(0.13),
          offset: const Offset(0, 3),
          blurRadius: 0,
        ),
      ],
    );

    if (icon != null && _isIconUrl(icon)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 52,
          child: Image.network(
            icon,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _dateFallback(decoration),
          ),
        ),
      );
    }

    if (icon != null) {
      return Container(
        width: 44,
        height: 52,
        decoration: decoration,
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 26)),
      );
    }

    return _dateFallback(decoration);
  }

  Widget _dateFallback(BoxDecoration decoration) {
    final start = event.startTime;
    return Container(
      width: 44,
      height: 52,
      decoration: decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _months[start.month - 1],
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
    );
  }
}
