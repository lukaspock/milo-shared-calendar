import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/event_photo.dart';
import '../models/poll.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/events_provider.dart';
import '../providers/photos_provider.dart';
import '../providers/polls_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/members_dialog.dart';

Widget _calIconChild(String icon, double tileSize, Color fallbackColor) {
  if (icon.startsWith('http://') || icon.startsWith('https://')) {
    final s = tileSize * 0.75;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(icon, width: s, height: s, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.calendar_today_rounded, size: tileSize * 0.42, color: fallbackColor)),
    );
  }
  return Text(icon, style: TextStyle(fontSize: tileSize * 0.45, height: 1.0));
}

class CalendarScreen extends ConsumerStatefulWidget {
  final String calendarId;
  const CalendarScreen({super.key, required this.calendarId});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

const double _kTabW = 90.0;

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  int _tabIndex = 0; // 0 = Calendar, 1 = Photos

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

  void _showUploadSheet(BuildContext context, String eventId, String eventTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PhotoUploadSheet(
        calendarId: widget.calendarId,
        eventId: eventId,
        eventTitle: eventTitle,
      ),
    );
  }

  void _showSelectEventSheet(BuildContext ctx, List<CalendarEvent> events) {
    final pastEvents = events
        .where((e) => e.endTime.isBefore(DateTime.now()))
        .toList()
      ..sort((a, b) => b.endTime.compareTo(a.endTime));

    if (pastEvents.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Noch keine vergangenen Events vorhanden')),
      );
      return;
    }

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: ctx.appColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ctx.appColors.line, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Für welches Event?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ctx.appColors.ink,
                ),
              ),
            ),
            Container(height: 1, color: ctx.appColors.line),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: pastEvents.length,
                separatorBuilder: (_, __) => Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: ctx.appColors.line,
                ),
                itemBuilder: (lCtx, i) {
                  final ev = pastEvents[i];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Text(
                      ev.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: ctx.appColors.ink,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('d. MMM yyyy').format(ev.startTime),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: ctx.appColors.inkMuted,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(lCtx);
                      _showUploadSheet(ctx, ev.id, ev.title);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPhoto(BuildContext ctx, EventPhoto photo) {
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhotoView(photo: photo),
        fullscreenDialog: true,
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

    final photos = calendar?.photoMode == true
        ? ref.watch(photosProvider(widget.calendarId)).valueOrNull ?? []
        : <EventPhoto>[];
    final currentUserId =
        ref.watch(authProvider.select((s) => s.user?.id)) ?? '';

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
                    child: calendar != null && calendarIcon(calendar) != null
                        ? _calIconChild(calendarIcon(calendar)!, 40, context.appColors.inkMuted)
                        : Icon(
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

                  // Check for photo banners (only for photo-mode calendars)
                  final now = DateTime.now();
                  CalendarEvent? activeEvent;
                  List<CalendarEvent> recentlyEndedEvents = [];
                  if (calendar?.photoMode == true) {
                    for (final e in events) {
                      if (e.startTime.isBefore(now) && e.endTime.isAfter(now)) {
                        activeEvent = e;
                        break;
                      }
                    }
                    recentlyEndedEvents = events.where((e) {
                      final age = now.difference(e.endTime);
                      return age.inHours >= 0 &&
                          age.inHours < 48 &&
                          e.endTime.isBefore(now) &&
                          !photos.any((p) =>
                              p.eventId == e.id &&
                              p.uploadedBy == currentUserId);
                    }).toList();
                  }

                  // ── Tab 0: Calendar ────────────────────────────────────
                  if (_tabIndex == 0) { return Column(
                    children: [
                      // Photo memory banners
                      if (activeEvent != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _PhotoBanner(
                            icon: '📸',
                            color: const Color(0xFFFFF3E0),
                            borderColor: const Color(0xFFE8A020),
                            iconColor: const Color(0xFFB07000),
                            message: 'Don\'t forget to take a photo!',
                            eventTitle: activeEvent.title,
                            actionLabel: 'Add photo',
                            onAction: () => _showUploadSheet(
                              context,
                              activeEvent!.id,
                              activeEvent.title,
                            ),
                          ),
                        ),
                      if (activeEvent == null && recentlyEndedEvents.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _PhotoBanner(
                            icon: '🖼',
                            color: const Color(0xFFE8F4FD),
                            borderColor: const Color(0xFF2196F3),
                            iconColor: const Color(0xFF1565C0),
                            message: 'Heb dir eine Erinnerung auf!',
                            eventTitle: recentlyEndedEvents.first.title,
                            actionLabel: 'Foto hochladen',
                            onAction: () => _showUploadSheet(
                              context,
                              recentlyEndedEvents.first.id,
                              recentlyEndedEvents.first.title,
                            ),
                          ),
                        ),

                      // ── Calendar card ─────────────────────────────────────
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

                      // ── Day header ────────────────────────────────────────
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

                      // ── Events + Polls ────────────────────────────────────
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            if (selectedEvents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                                      bottom: e.key < selectedEvents.length - 1
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
                                      borderRadius: BorderRadius.circular(6),
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
                                      bottom: e.key < openPolls.length - 1
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
                  ); }

                  // ── Tab 1: Photos grid ─────────────────────────────────────
                  if (photos.isEmpty) { return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 48, color: context.appColors.inkMuted),
                        const SizedBox(height: 12),
                        Text(
                          calendar?.photoMode == true
                              ? 'No photos yet – create some memories!'
                              : 'Photo mode is not enabled for this calendar.',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.appColors.inkMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ); }

                  return Column(
                    children: [
                      // Upload button row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Text(
                              'MEMORIES',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: context.appColors.inkMuted,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showSelectEventSheet(context, events),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: context.appColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.appColors.line, width: 1.5),
                                ),
                                child: Text(
                                  '+ Photo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: context.appColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 2-column photo grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: photos.length,
                          itemBuilder: (ctx, i) {
                            final photo = photos[i];
                            final date = photo.eventStartTime ?? photo.createdAt;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('d. MMM yyyy').format(date),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.appColors.inkMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: _PhotoCard(
                                    photo: photo,
                                    currentUserId: currentUserId,
                                    onDelete: () async {
                                      final ok = await ref
                                          .read(photosProvider(widget.calendarId).notifier)
                                          .deletePhoto(photo.eventId, photo.id);
                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Fehler beim Löschen')),
                                        );
                                      }
                                    },
                                    onTap: () => _showFullScreenPhoto(context, photo),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ── Bottom tab bar (left-aligned island, sliding pill) ───────
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Container(
                  width: 2 * _kTabW + 8,
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: context.appColors.line, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: context.appColors.ink.withOpacity(0.06),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        left: 4.0 + _tabIndex * _kTabW,
                        top: 4,
                        width: _kTabW,
                        bottom: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: _kTabW,
                              child: _buildTabItem(
                                context: context,
                                icon: Icons.calendar_today_rounded,
                                label: 'Calendar',
                                selected: _tabIndex == 0,
                                onTap: () => setState(() => _tabIndex = 0),
                              ),
                            ),
                            SizedBox(
                              width: _kTabW,
                              child: _buildTabItem(
                                context: context,
                                icon: Icons.photo_library_rounded,
                                label: 'Photos',
                                selected: _tabIndex == 1,
                                onTap: () => setState(() => _tabIndex = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabIndex == 0
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.ink.withOpacity(0.33),
                    offset: const Offset(0, 4),
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
            )
          : null,
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const softOrange = Color(0xFFFF8C4B);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? softOrange : context.appColors.inkMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? softOrange : context.appColors.inkMuted,
              ),
            ),
          ],
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

// ── Photo banner (event starting / event ended) ───────────────────────────────

class _PhotoBanner extends StatelessWidget {
  const _PhotoBanner({
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.message,
    required this.eventTitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String icon;
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final String message;
  final String eventTitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                Text(
                  eventTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: iconColor.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo card (in memories feed) ────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.currentUserId,
    required this.onDelete,
    required this.onTap,
  });

  final EventPhoto photo;
  final String currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canDelete = photo.uploadedBy == currentUserId;
    return GestureDetector(
      onTap: onTap,
      onLongPress: canDelete
          ? () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(
                    'Foto löschen?',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  content: Text(
                    'Dieses Foto wird für alle Mitglieder gelöscht.',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: Text(
                        'Löschen',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ),
                  ],
                ),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: context.appColors.line.withOpacity(0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                photo.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: context.appColors.surfaceSoft,
                  child: Icon(Icons.broken_image_rounded,
                      color: context.appColors.inkMuted, size: 40),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (photo.eventTitle != null)
                      Text(
                        photo.eventTitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${photo.uploadedByName ?? 'Jemand'} · ${DateFormat('d. MMM').format(photo.createdAt)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

// ── Photo upload bottom sheet ─────────────────────────────────────────────────

class _PhotoUploadSheet extends ConsumerStatefulWidget {
  const _PhotoUploadSheet({
    required this.calendarId,
    required this.eventId,
    required this.eventTitle,
  });

  final String calendarId;
  final String eventId;
  final String eventTitle;

  @override
  ConsumerState<_PhotoUploadSheet> createState() => _PhotoUploadSheetState();
}

class _PhotoUploadSheetState extends ConsumerState<_PhotoUploadSheet> {
  File? _selectedFile;
  bool _uploading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _selectedFile = File(picked.path);
      _error = null;
    });
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final ok = await ref
        .read(photosProvider(widget.calendarId).notifier)
        .addPhoto(widget.eventId, _selectedFile!);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto hochgeladen!')),
      );
    } else {
      setState(() {
        _uploading = false;
        _error = 'Upload fehlgeschlagen. Bitte erneut versuchen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                '📸 Erinnerungsfoto',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.ink,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: context.appColors.inkMuted),
              ),
            ],
          ),
          Text(
            widget.eventTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: context.appColors.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          if (_selectedFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedFile!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: context.appColors.line, width: 1.5),
                    foregroundColor: context.appColors.ink,
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    'Galerie',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: context.appColors.line, width: 1.5),
                    foregroundColor: context.appColors.ink,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    'Kamera',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),

          if (_selectedFile != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Foto hochladen',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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

// ── Full-screen photo viewer ───────────────────────────────────────────────────

class _FullScreenPhotoView extends StatelessWidget {
  const _FullScreenPhotoView({required this.photo});
  final EventPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          photo.eventTitle ?? '',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            photo.photoUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_rounded,
              color: Colors.white54,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}
