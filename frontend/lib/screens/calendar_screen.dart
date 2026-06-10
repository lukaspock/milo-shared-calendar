import 'dart:math' show max;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/calendar.dart';
import '../models/event.dart' show CalendarEvent, EventSource;
import '../models/event_photo.dart';
import '../models/poll.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/events_provider.dart';
import '../providers/photos_provider.dart';
import '../providers/polls_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/members_dialog.dart';
import 'chat_screen.dart';

Widget _calIconChild(String icon, double tileSize, Color fallbackColor) {
  if (icon.startsWith('http://') || icon.startsWith('https://')) {
    final s = tileSize * 0.75;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        icon,
        width: s,
        height: s,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.calendar_today_rounded,
          size: tileSize * 0.42,
          color: fallbackColor,
        ),
      ),
    );
  }
  return Text(icon, style: TextStyle(fontSize: tileSize * 0.45, height: 1.0));
}

Color? _hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  final String calendarId;
  const CalendarScreen({super.key, required this.calendarId});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

const double _kTabW = 96.0;

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  String _viewMode = 'monthly';
  int _tabIndex = 1; // 0 = Chat, 1 = Calendar, 2 = Photos

  @override
  void initState() {
    super.initState();
    _viewMode = calendarViewFor(widget.calendarId);
    if (!isColorPromptedFor(widget.calendarId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showColorPromptSheet();
      });
    }
  }

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

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CalendarSettingsSheet(
        calendarId: widget.calendarId,
        viewMode: _viewMode,
        onViewModeChanged: (mode) => setState(() => _viewMode = mode),
      ),
    );
  }

  void _showColorPromptSheet() {
    markColorPrompted(widget.calendarId);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => const _ColorPickerSheet(),
    );
  }

  void _showUploadSheet(
    BuildContext context,
    String eventId,
    String eventTitle,
  ) {
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
    final pastEvents =
        events.where((e) => e.endTime.isBefore(DateTime.now())).toList()
          ..sort((a, b) => b.endTime.compareTo(a.endTime));

    if (pastEvents.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Noch keine vergangenen Events vorhanden'),
        ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
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
    // rootNavigator: true ensures we push above GoRouter's navigator so
    // the AppBar back button pops only the photo overlay, not the calendar
    Navigator.of(ctx, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPhotoView(photo: photo),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If this calendar was deleted by the owner while we are on this screen,
    // the CalendarNotifier removes it from state — navigate back to home.
    ref.listen(calendarProvider, (_, next) {
      next.whenData((list) {
        if (!list.any((c) => c.id == widget.calendarId) && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This calendar has been deleted.')),
          );
          context.go('/home');
        }
      });
    });

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
        bottom: !kIsWeb,
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

                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: calendar != null && calendarIcon(calendar) != null
                        ? _calIconChild(
                            calendarIcon(calendar)!,
                            40,
                            context.appColors.inkMuted,
                          )
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
                          border: Border.all(
                            color: context.appColors.line,
                            width: 1.5,
                          ),
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
                    onTap: _showSettingsSheet,
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
                        Icons.tune_rounded,
                        size: 18,
                        color: context.appColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(eventsProvider(widget.calendarId).notifier)
                          .fetch();
                      if (calendar?.photoMode == true) {
                        ref
                            .read(photosProvider(widget.calendarId).notifier)
                            .fetch();
                      }
                    },
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
                  child: CircularProgressIndicator(
                    color: context.appColors.ink,
                  ),
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
                      if (e.source != EventSource.sharedcal) continue;
                      if (e.startTime.isBefore(now) && e.endTime.isAfter(now)) {
                        activeEvent = e;
                        break;
                      }
                    }
                    recentlyEndedEvents = events.where((e) {
                      if (e.source != EventSource.sharedcal) return false;
                      final age = now.difference(e.endTime);
                      return age.inHours >= 0 &&
                          age.inHours < 48 &&
                          e.endTime.isBefore(now) &&
                          !photos.any(
                            (p) =>
                                p.eventId == e.id &&
                                p.uploadedBy == currentUserId,
                          );
                    }).toList();
                  }

                  // ── Tab 0: Chat ────────────────────────────────────────
                  if (_tabIndex == 0) {
                    return ChatView(
                      calendarId: widget.calendarId,
                      currentUserId: currentUserId,
                      calDeepColor: calHue.deep,
                    );
                  }

                  // ── Tab 1: Calendar ────────────────────────────────────
                  if (_tabIndex == 1) {
                    if (_viewMode == 'weekly') {
                      return Column(
                        children: [
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
                          if (activeEvent == null &&
                              recentlyEndedEvents.isNotEmpty)
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
                          Expanded(
                            child: _WeeklyView(
                              events: events,
                              calendarId: widget.calendarId,
                              calHue: calHue,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
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
                        if (activeEvent == null &&
                            recentlyEndedEvents.isNotEmpty)
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
                            decoration: calendar?.photoMode == true
                                ? null
                                : BoxDecoration(
                                    color: context.appColors.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: context.appColors.line,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.appColors.line.withOpacity(
                                          0.5,
                                        ),
                                        offset: const Offset(0, 4),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                            padding: calendar?.photoMode == true
                                ? EdgeInsets.zero
                                : EdgeInsets.all(kIsWeb ? 18 : 12),
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
                                  DateFormat(
                                    'EEE, MMM d',
                                  ).format(_selectedDay!).toUpperCase(),
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

                        // ── Events + Polls ────────────────────────────────────
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              if (selectedEvents.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                                          : 0,
                                    ),
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
                                          : 0,
                                    ),
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
                  }

                  // ── Tab 2: Photos grid ─────────────────────────────────────
                  if (photos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: context.appColors.inkMuted,
                          ),
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
                    );
                  }

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
                              onTap: () =>
                                  _showSelectEventSheet(context, events),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.appColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: context.appColors.line,
                                    width: 1.5,
                                  ),
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
                      // Photo grid — 2 cols on mobile, more on web/wide screens
                      Expanded(
                        child: LayoutBuilder(
                          builder: (ctx, constraints) {
                            final cols = kIsWeb
                                ? (constraints.maxWidth ~/ 220).clamp(2, 6)
                                : 2;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: photos.length,
                              itemBuilder: (ctx, i) {
                                final photo = photos[i];
                                final date =
                                    photo.eventStartTime ?? photo.createdAt;
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
                                              .read(
                                                photosProvider(
                                                  widget.calendarId,
                                                ).notifier,
                                              )
                                              .deletePhoto(
                                                photo.eventId,
                                                photo.id,
                                              );
                                          if (!ok && context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Fehler beim Löschen',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onTap: () => _showFullScreenPhoto(
                                          context,
                                          photo,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ── Bottom tab bar (always visible) ──────────────────────────
            _buildTabIsland(context, calendar),
          ],
        ),
      ),
      floatingActionButton: _tabIndex == 1
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
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

  Widget _buildTabIsland(BuildContext context, CalendarModel? cal) {
    final hasPhotos = cal?.photoMode == true;
    final unread = ref.watch(chatProvider(widget.calendarId)).unreadCount;
    final tabCount = hasPhotos ? 3 : 2;
    final totalWidth = tabCount * _kTabW + 8.0;

    // Map logical tab positions: Chat=0, Calendar=1, Photos=2
    final tabs = [
      (icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chat', index: 0),
      (icon: Icons.calendar_today_rounded, activeIcon: Icons.calendar_month_rounded, label: 'Calendar', index: 1),
      if (hasPhotos)
        (icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library_rounded, label: 'Photos', index: 2),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, kIsWeb ? 4 : 6, 16, kIsWeb ? 6 : 10),
        child: Container(
          width: totalWidth,
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
                  children: tabs.map((t) {
                    final isSelected = _tabIndex == t.index;
                    return SizedBox(
                      width: _kTabW,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildTabItem(
                            context: context,
                            icon: isSelected ? t.activeIcon : t.icon,
                            label: t.label,
                            selected: isSelected,
                            onTap: () {
                              setState(() => _tabIndex = t.index);
                              if (t.index == 0) {
                                ref.read(chatProvider(widget.calendarId).notifier).markAsRead();
                              }
                            },
                          ),
                          // Unread badge on Chat tab
                          if (t.index == 0 && unread > 0)
                            Positioned(
                              top: 4,
                              right: 18,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                child: Text(
                                  unread > 9 ? '9+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
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
        padding: EdgeInsets.symmetric(vertical: kIsWeb ? 8 : 10),
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
              child: Center(child: AppImages.poll(size: 20)),
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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: kIsWeb ? 4 : 2,
            crossAxisSpacing: kIsWeb ? 4 : 2,
            mainAxisExtent: kIsWeb ? 58 : 46,
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
          SizedBox(height: kIsWeb ? 6 : 4),
          Text(
            '$day',
            style: GoogleFonts.plusJakartaSans(
              fontSize: kIsWeb ? 12 : 11,
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
                      if (widget.event.source == EventSource.googleImport) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 12,
                          color: context.appColors.inkMuted,
                        ),
                      ] else if (widget.event.source ==
                          EventSource.deviceImport) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.phone_iphone_rounded,
                          size: 12,
                          color: context.appColors.inkMuted,
                        ),
                      ],
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

bool _isIconUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

const _months = [
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
    final single = events.length == 1;
    final creatorColor = (single && events[0].source != EventSource.sharedcal)
        ? _hexToColor(events[0].creatorColor)
        : null;
    final bg = creatorColor != null
        ? creatorColor.withOpacity(isSelected ? 0.35 : 0.22)
        : isSelected
            ? calHue.dot.withOpacity(0.25)
            : calHue.bg;
    final icon = single ? events[0].icon : null;

    if (single && icon != null && _isIconUrl(icon)) {
      return SizedBox(
        width: double.infinity,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              icon,
              width: 20,
              height: 20,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _textBadge(events[0].title, bg),
            ),
          ),
        ),
      );
    }

    if (single && icon != null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 11, height: 1.3)),
      );
    }

    return _textBadge(single ? events[0].title : '+${events.length}', bg);
  }

  Widget _textBadge(String text, Color bg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
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
    final creatorColor = event.source != EventSource.sharedcal
        ? _hexToColor(event.creatorColor)
        : null;
    final decoration = BoxDecoration(
      color: creatorColor != null ? creatorColor.withOpacity(0.2) : hue.bg,
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
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
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: context.appColors.inkMuted,
                    size: 40,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
  XFile? _selectedFile;
  Uint8List? _imageBytes;
  bool _uploading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedFile = picked;
      _imageBytes = bytes;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto hochgeladen!')));
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
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
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
                icon: Icon(
                  Icons.close_rounded,
                  color: context.appColors.inkMuted,
                ),
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

          if (_imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _imageBytes!,
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
                  onPressed: _uploading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: context.appColors.line, width: 1.5),
                    foregroundColor: context.appColors.ink,
                  ),
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(
                    'Galerie',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: context.appColors.line, width: 1.5),
                    foregroundColor: context.appColors.ink,
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    'Kamera',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
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
                    borderRadius: BorderRadius.circular(28),
                  ),
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

// ── Profile colors (same palette as home screen) ──────────────────────────────

const _profileColors = [
  '#6C63FF', '#FF6584', '#43B89C', '#F5A623',
  '#4A90E2', '#E74C3C', '#2ECC71', '#9B59B6',
];

// ── Event layout info ─────────────────────────────────────────────────────────

class _EventLayoutInfo {
  const _EventLayoutInfo({
    required this.event,
    required this.col,
    required this.totalCols,
  });
  final CalendarEvent event;
  final int col;
  final int totalCols;
}

// ── Weekly view ───────────────────────────────────────────────────────────────

class _WeeklyView extends StatefulWidget {
  const _WeeklyView({
    required this.events,
    required this.calendarId,
    required this.calHue,
  });
  final List<CalendarEvent> events;
  final String calendarId;
  final CalHue calHue;

  @override
  State<_WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends State<_WeeklyView> {
  static const double _hourH = 60.0;
  static const double _labelW = 44.0;
  static const int _initialPage = 500;

  late PageController _pageController;
  final _scrollController = ScrollController();
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _pageController = PageController(initialPage: _initialPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(7 * _hourH);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _mondayOf(DateTime date) {
    final d = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - d);
  }

  DateTime _weekStartForPage(int page) {
    final offset = page - _initialPage;
    return _mondayOf(DateTime.now()).add(Duration(days: 7 * offset));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekLabel(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${DateFormat('MMM d').format(monday)} – ${DateFormat('d, yyyy').format(sunday)}';
    }
    return '${DateFormat('MMM d').format(monday)} – ${DateFormat('MMM d, yyyy').format(sunday)}';
  }

  String _hourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Week navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                ),
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
                    _weekLabel(_weekStart),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.ink,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                ),
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
        ),
        const SizedBox(height: 8),
        // Day header aligned with grid columns
        Padding(
          padding: const EdgeInsets.only(left: _labelW),
          child: Row(
            children: List.generate(7, (i) {
              final day = _weekStart.add(Duration(days: i));
              final isToday = _isSameDay(day, now);
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.inkMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: isToday
                          ? BoxDecoration(
                              color: widget.calHue.deep,
                              shape: BoxShape.circle,
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.w500,
                          color:
                              isToday ? Colors.white : context.appColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: context.appColors.line),
        // Scrollable time grid
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: 24 * _hourH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hour label column
                  SizedBox(
                    width: _labelW,
                    child: Stack(
                      children: List.generate(24, (hour) {
                        return Positioned(
                          top: hour * _hourH - 7,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _hourLabel(hour),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: context.appColors.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Week pages (horizontal PageView)
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() => _weekStart = _weekStartForPage(page));
                      },
                      itemBuilder: (ctx, page) {
                        final weekStart = _weekStartForPage(page);
                        return _WeekGridPage(
                          weekStart: weekStart,
                          events: widget.events,
                          calendarId: widget.calendarId,
                          hourH: _hourH,
                          appColors: context.appColors,
                          calHue: widget.calHue,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── One page of the weekly grid (7 day columns) ───────────────────────────────

class _WeekGridPage extends StatelessWidget {
  const _WeekGridPage({
    required this.weekStart,
    required this.events,
    required this.calendarId,
    required this.hourH,
    required this.appColors,
    required this.calHue,
  });

  final DateTime weekStart;
  final List<CalendarEvent> events;
  final String calendarId;
  final double hourH;
  final AppColors appColors;
  final CalHue calHue;

  bool _isCurrentWeek(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final sunday = weekStart.add(const Duration(days: 6));
    return !today.isBefore(weekStart) && !today.isAfter(sunday);
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return events.where((e) {
      final eStart =
          DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final eEnd = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
      return !dayKey.isBefore(eStart) && !dayKey.isAfter(eEnd);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final colW = constraints.maxWidth / 7;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Horizontal hour lines
            ...List.generate(
              24,
              (hour) => Positioned(
                top: hour * hourH,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: appColors.line.withOpacity(0.5),
                ),
              ),
            ),
            // Vertical day dividers
            ...List.generate(
              6,
              (i) => Positioned(
                left: (i + 1) * colW,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: appColors.line.withOpacity(0.4),
                ),
              ),
            ),
            // Events per day column
            ...List.generate(7, (dayIndex) {
              final day = weekStart.add(Duration(days: dayIndex));
              final dayEvents = _eventsForDay(day);
              return Positioned(
                left: dayIndex * colW,
                width: colW,
                top: 0,
                bottom: 0,
                child: _DayColumn(
                  date: day,
                  events: dayEvents,
                  calendarId: calendarId,
                  hourH: hourH,
                  colW: colW,
                  calHue: calHue,
                ),
              );
            }),
            // Current time indicator
            if (_isCurrentWeek(now)) (() {
              final dayIdx = now.weekday - 1;
              final minuteOfDay = now.hour * 60 + now.minute;
              final top = minuteOfDay * (hourH / 60.0);
              return Positioned(
                top: top,
                left: dayIdx * colW + 2,
                width: colW - 4,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              );
            })(),
          ],
        );
      },
    );
  }
}

// ── Single day column ─────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.events,
    required this.calendarId,
    required this.hourH,
    required this.colW,
    required this.calHue,
  });

  final DateTime date;
  final List<CalendarEvent> events;
  final String calendarId;
  final double hourH;
  final double colW;
  final CalHue calHue;

  DateTime _effectiveStart(CalendarEvent e) {
    final startDay =
        DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    if (startDay.isBefore(targetDay)) {
      return DateTime(date.year, date.month, date.day, 0, 0);
    }
    return e.startTime;
  }

  DateTime _effectiveEnd(CalendarEvent e) {
    final endDay = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    if (endDay.isAfter(targetDay)) {
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
    return e.endTime;
  }

  List<_EventLayoutInfo> _assignColumns(List<CalendarEvent> sorted) {
    final cols = <int, List<CalendarEvent>>{};
    final assigned = <CalendarEvent, int>{};

    for (final e in sorted) {
      final eStart = _effectiveStart(e);
      final eEnd = _effectiveEnd(e);
      int col = 0;
      while (true) {
        final colEvents = cols[col] ?? [];
        final overlaps = colEvents.any((other) {
          final oStart = _effectiveStart(other);
          final oEnd = _effectiveEnd(other);
          return oStart.isBefore(eEnd) && oEnd.isAfter(eStart);
        });
        if (!overlaps) break;
        col++;
      }
      assigned[e] = col;
      cols.putIfAbsent(col, () => []).add(e);
    }

    return sorted.map((e) {
      final col = assigned[e]!;
      final eStart = _effectiveStart(e);
      final eEnd = _effectiveEnd(e);
      int maxCol = col;
      for (final other in sorted) {
        if (other != e) {
          final oStart = _effectiveStart(other);
          final oEnd = _effectiveEnd(other);
          if (oStart.isBefore(eEnd) && oEnd.isAfter(eStart)) {
            maxCol = max(maxCol, assigned[other]!);
          }
        }
      }
      return _EventLayoutInfo(event: e, col: col, totalCols: maxCol + 1);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]
      ..sort((a, b) => _effectiveStart(a).compareTo(_effectiveStart(b)));
    final layouts = _assignColumns(sorted);

    return Stack(
      children: layouts.map((layout) {
        final e = layout.event;
        final start = _effectiveStart(e);
        final end = _effectiveEnd(e);
        final startMinutes = start.hour * 60 + start.minute;
        final endMinutes = end.hour * 60 + end.minute;
        final durationMins =
            (endMinutes - startMinutes).clamp(15, 24 * 60).toDouble();
        final top = startMinutes * (hourH / 60.0);
        final height = durationMins * (hourH / 60.0);

        final usableW = colW - 4;
        final eventW = usableW / layout.totalCols;
        final left = 2.0 + layout.col * eventW;

        return Positioned(
          top: top + 1,
          left: left,
          width: eventW - 1,
          height: height - 2,
          child: _WeekEventBox(
            event: e,
            height: height,
            calendarId: calendarId,
            calHue: calHue,
          ),
        );
      }).toList(),
    );
  }
}

// ── Event box in the weekly grid ──────────────────────────────────────────────

class _WeekEventBox extends StatelessWidget {
  const _WeekEventBox({
    required this.event,
    required this.height,
    required this.calendarId,
    required this.calHue,
  });

  final CalendarEvent event;
  final double height;
  final String calendarId;
  final CalHue calHue;

  Color _eventColor() {
    if (event.source != EventSource.sharedcal) {
      final c = _hexToColor(event.creatorColor);
      if (c != null) return c.withOpacity(0.85);
    }
    return calHue.deep.withOpacity(0.85);
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = _eventColor();
    final showTime = height >= 36;

    return GestureDetector(
      onTap: () => context.go(
        '/calendar/$calendarId/event/${event.id}',
        extra: event,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showTime)
              Text(
                '${_fmt(event.startTime)}–${_fmt(event.endTime)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

// ── View mode tile ────────────────────────────────────────────────────────────

class _ViewModeTile extends StatelessWidget {
  const _ViewModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.appColors.surfaceSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? context.appColors.ink : context.appColors.line,
              width: selected ? 2.0 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? context.appColors.ink
                    : context.appColors.inkMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? context.appColors.ink
                      : context.appColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Calendar settings bottom sheet ───────────────────────────────────────────

class _CalendarSettingsSheet extends ConsumerWidget {
  const _CalendarSettingsSheet({
    required this.calendarId,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final String calendarId;
  final String viewMode;
  final ValueChanged<String> onViewModeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));

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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Calendar Settings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appColors.ink,
              ),
            ),
          ),
          Container(height: 1, color: context.appColors.line),
          // View mode section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIEW',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.inkMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ViewModeTile(
                      label: 'Monthly',
                      icon: Icons.calendar_view_month_rounded,
                      selected: viewMode == 'monthly',
                      onTap: () {
                        onViewModeChanged('monthly');
                        persistCalendarView(calendarId, 'monthly');
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    _ViewModeTile(
                      label: 'Weekly',
                      icon: Icons.calendar_view_week_rounded,
                      selected: viewMode == 'weekly',
                      onTap: () {
                        onViewModeChanged('weekly');
                        persistCalendarView(calendarId, 'weekly');
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            color: context.appColors.line,
          ),
          // Event color section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MY EVENT COLOR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.inkMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _profileColors.map((hex) {
                    final c = Color(
                        int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
                    final isSelected = user?.color == hex;
                    return GestureDetector(
                      onTap: () => ref
                          .read(authProvider.notifier)
                          .updateProfile(color: hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: context.appColors.ink,
                                  width: 2.5,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── First-open color picker sheet ────────────────────────────────────────────

class _ColorPickerSheet extends ConsumerStatefulWidget {
  const _ColorPickerSheet();

  @override
  ConsumerState<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<_ColorPickerSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(authProvider.select((s) => s.user?.color));
  }

  Future<void> _save() async {
    if (_selected != null) {
      await ref.read(authProvider.notifier).updateProfile(color: _selected);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wähle deine Farbe',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.appColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Diese Farbe sehen andere Mitglieder bei deinen importierten Events aus Google Kalender und Gerätekalender.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _profileColors.map((hex) {
              final c = Color(
                  int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
              final isSelected = _selected == hex;
              return GestureDetector(
                onTap: () => setState(() => _selected = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: context.appColors.ink, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.withOpacity(0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: _selected != null
                    ? Color(int.parse(
                        'FF${_selected!.replaceFirst('#', '')}',
                        radix: 16))
                    : context.appColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Speichern',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
