import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/calendar.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/device_calendar_service.dart';
import '../services/local_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/notification_type_selector.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(calendarProvider);
    final user = ref.watch(authProvider).user;
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: context.appColors.bg,
      body: SafeArea(
        child: calendarsAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: context.appColors.ink),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appColors.line, width: 1.5),
                  ),
                  child: Icon(Icons.cloud_off_rounded, color: context.appColors.inkMuted, size: 28),
                ),
                const SizedBox(height: 16),
                Text('Could not load calendars',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(calendarProvider.notifier).fetch(),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
          data: (calendars) {
            final myCalendars = calendars.where((c) => c.isOwner).toList();
            final sharedCalendars = calendars.where((c) => !c.isOwner).toList();

            return RefreshIndicator(
              onRefresh: () => ref.read(calendarProvider.notifier).fetch(),
              color: context.appColors.ink,
              backgroundColor: context.appColors.surface,
              child: CustomScrollView(
                slivers: [
                  // ── Header ────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.appColors.inkMuted,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user != null
                                      ? 'Hey, ${user.name.split(' ').first} 👋'
                                      : 'Milo',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: context.appColors.ink,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CircleButton(
                            icon: Icons.settings_rounded,
                            onTap: () => _showSettingsSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Up Next card ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _UpNextCard(
                        calendars: calendars,
                        calendarId: calendars.isNotEmpty ? calendars.first.id : null,
                        onTap: calendars.isNotEmpty
                            ? () => _openCalendar(context, ref, calendars.first)
                            : null,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // ── My calendars ──────────────────────────────────────────
                  if (myCalendars.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _SectionHeader(title: 'My calendars', count: myCalendars.length),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList.separated(
                        itemCount: myCalendars.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final cal = myCalendars[i];
                          return Dismissible(
                            key: ValueKey(cal.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDeleteCalendar(ctx, cal.name),
                            onDismissed: (_) => ref
                                .read(calendarProvider.notifier)
                                .deleteCalendar(cal.id),
                            background: _DismissBackground(
                              color: AppTheme.danger,
                              icon: Icons.delete_outline_rounded,
                            ),
                            child: _CalendarCard(
                              calendar: cal,
                              onTap: () => _openCalendar(context, ref, cal),
                              onDelete: () async {
                                final ok = await _confirmDeleteCalendar(ctx, cal.name);
                                if (ok == true && ctx.mounted) {
                                  ref.read(calendarProvider.notifier).deleteCalendar(cal.id);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],

                  // ── Shared with me ────────────────────────────────────────
                  if (sharedCalendars.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _SectionHeader(title: 'Shared with me', count: sharedCalendars.length),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList.separated(
                        itemCount: sharedCalendars.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final cal = sharedCalendars[i];
                          return Dismissible(
                            key: ValueKey(cal.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmLeaveCalendar(ctx, cal.name),
                            onDismissed: (_) => ref
                                .read(calendarProvider.notifier)
                                .leaveCalendar(cal.id),
                            background: _DismissBackground(
                              color: const Color(0xFFE87A35),
                              icon: Icons.logout_rounded,
                            ),
                            child: _CalendarCard(
                              calendar: cal,
                              onTap: () => _openCalendar(context, ref, cal),
                              onDelete: () async {
                                final ok = await _confirmLeaveCalendar(ctx, cal.name);
                                if (ok == true && ctx.mounted) {
                                  ref.read(calendarProvider.notifier).leaveCalendar(cal.id);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],

                  if (calendars.isEmpty)
                    SliverFillRemaining(
                      child: _EmptyState(onCreateTap: () => _showCreateSheet(context, ref)),
                    ),

                  // bottom FAB padding
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _PillFAB(
            heroTag: 'join',
            label: 'Join calendar',
            isSecondary: true,
            onTap: () => _showJoinSheet(context, ref),
          ),
          const SizedBox(height: 10),
          _PillFAB(
            heroTag: 'create',
            label: '+ New calendar',
            isSecondary: false,
            onTap: () => _showCreateSheet(context, ref),
          ),
        ],
      ),
    );
  }

  void _openCalendar(BuildContext context, WidgetRef ref, CalendarModel cal) {
    ref.read(selectedCalendarProvider.notifier).state = cal.id;
    context.go('/calendar/${cal.id}');
  }

  Future<bool?> _confirmDeleteCalendar(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('This will permanently delete the calendar and all its events and polls.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLeaveCalendar(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave "$name"?'),
        content: const Text('You will no longer have access to this calendar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE87A35)),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _SettingsSheet(),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCalendarSheet(ctrl: ctrl, ref: ref),
    );
  }

  void _showJoinSheet(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JoinCalendarSheet(ctrl: ctrl, ref: ref),
    );
  }
}

// ── Up Next card ──────────────────────────────────────────────────────────────

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.calendars, this.calendarId, this.onTap});
  final List<CalendarModel> calendars;
  final String? calendarId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hue = calendars.isNotEmpty ? hueFor(calendars.first) : stickerHues[0];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? hue.darkBg : hue.bg;
    final textColor = isDark ? context.appColors.ink : hue.ink;
    final subColor = isDark ? context.appColors.inkSoft : hue.dot;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: isDark ? Border.all(color: context.appColors.line, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: hue.deep.withOpacity(isDark ? 0.0 : 0.13),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: hue.deep.withOpacity(isDark ? 0.0 : 0.08),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AppImages.calendar(size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UP NEXT · TODAY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calendars.isEmpty ? 'No calendars yet' : 'Open ${calendars.first.name}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    calendars.isEmpty
                        ? 'Create a calendar to get started'
                        : '${calendars.first.memberCount} members · ${calendars.first.inviteCode}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textColor, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appColors.inkMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: context.appColors.surfaceSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.line, width: 1),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.appColors.inkMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: context.appColors.line, thickness: 1)),
      ],
    );
  }
}

// ── Calendar card ─────────────────────────────────────────────────────────────

class _CalendarCard extends StatefulWidget {
  const _CalendarCard({required this.calendar, required this.onTap, this.onDelete});
  final CalendarModel calendar;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hue = hueFor(widget.calendar);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: context.appColors.line.withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Sticker tile
            StickerTile(
              hue: hue,
              size: 48,
              radius: 14,
              child: Icon(Icons.calendar_today_rounded, size: 20, color: context.appColors.inkMuted),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.calendar.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Member avatar stack
                      _MemberDots(hue: hue, count: widget.calendar.memberCount),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${widget.calendar.memberCount} member${widget.calendar.memberCount == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: context.appColors.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Role chip
                      Builder(builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? hue.darkBg : hue.bg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.calendar.isOwner ? 'Owner' : 'Member',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? context.appColors.inkSoft : hue.ink,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Footer
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.calendar.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code copied: ${widget.calendar.inviteCode}')),
                      );
                    },
                    child: Text(
                      'code ${widget.calendar.inviteCode}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: context.appColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.onDelete != null)
              GestureDetector(
                onTap: widget.onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    widget.calendar.isOwner
                        ? Icons.delete_outline_rounded
                        : Icons.exit_to_app_rounded,
                    color: widget.calendar.isOwner
                        ? AppTheme.danger
                        : const Color(0xFFE87A35),
                    size: 22,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: context.appColors.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MemberDots extends StatelessWidget {
  const _MemberDots({required this.hue, required this.count});
  final CalHue hue;
  final int count;

  @override
  Widget build(BuildContext context) {
    final show = count.clamp(0, 3);
    return SizedBox(
      width: 8.0 + show * 14.0,
      height: 20,
      child: Stack(
        children: List.generate(show, (i) => Positioned(
          left: i * 14.0,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: hue.dot,
              shape: BoxShape.circle,
              border: Border.all(color: context.appColors.surface, width: 2),
            ),
          ),
        )),
      ),
    );
  }
}

// ── Circle action button ──────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: context.appColors.line.withOpacity(0.5),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: context.appColors.ink),
      ),
    );
  }
}

// ── Pill FAB ──────────────────────────────────────────────────────────────────

class _PillFAB extends StatelessWidget {
  const _PillFAB({
    required this.heroTag,
    required this.label,
    required this.isSecondary,
    required this.onTap,
  });
  final Object heroTag;
  final String label;
  final bool isSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSecondary ? context.appColors.surface : context.appColors.ink;
    final fg = isSecondary ? context.appColors.ink : context.appColors.bg;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: isSecondary ? Border.all(color: context.appColors.line, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: isSecondary
                  ? context.appColors.line.withOpacity(0.5)
                  : context.appColors.ink.withOpacity(0.33),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Dismiss background ────────────────────────────────────────────────────────

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StickerTile(
              hue: stickerHues[0],
              size: 80,
              radius: 22,
              child: AppImages.calendar(size: 34),
            ),
            const SizedBox(height: 24),
            Text('No calendars yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create a calendar to get started, or join one with an invite code.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: onCreateTap,
                child: const Text('Create calendar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create calendar bottom sheet ──────────────────────────────────────────────

class _CreateCalendarSheet extends StatefulWidget {
  const _CreateCalendarSheet({required this.ctrl, required this.ref});
  final TextEditingController ctrl;
  final WidgetRef ref;

  @override
  State<_CreateCalendarSheet> createState() => _CreateCalendarSheetState();
}

class _CreateCalendarSheetState extends State<_CreateCalendarSheet> {
  int _selectedHue = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grabber
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
                'New calendar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: context.appColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hue preview tile
          Center(
            child: StickerTile(
              hue: stickerHues[_selectedHue],
              size: 96,
              radius: 28,
              child: AppImages.calendar(size: 38),
            ),
          ),
          const SizedBox(height: 20),

          // Name field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'CALENDAR NAME',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: context.appColors.inkMuted, letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appColors.line, width: 1.5),
                ),
                child: TextField(
                  controller: widget.ctrl,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.appColors.ink, fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Family, Work, Friends…',
                    hintStyle: GoogleFonts.plusJakartaSans(color: context.appColors.inkMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hue swatches
          Text(
            'COLOR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: context.appColors.inkMuted, letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stickerHues.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == _selectedHue;
                return GestureDetector(
                  onTap: () => setState(() => _selectedHue = i),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: stickerHues[i].bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? context.appColors.ink : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    side: BorderSide(color: context.appColors.line, width: 1.5),
                    foregroundColor: context.appColors.ink,
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () async {
                    if (widget.ctrl.text.trim().isEmpty) return;
                    final name = widget.ctrl.text.trim();
                    final chosenHue = _selectedHue;
                    Navigator.pop(context);
                    final cal = await widget.ref
                        .read(calendarProvider.notifier)
                        .createCalendar(name);
                    if (cal != null) {
                      await persistCalendarHue(cal.id, chosenHue);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Created! Code: ${cal.inviteCode}')),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Create calendar',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings bottom sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet>
    with WidgetsBindingObserver {
  bool _calendarsExpanded = false;
  bool _connecting = false;
  bool _connectingDevice = false;
  bool _deviceCalendarConnected = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeviceCalendarState();
  }

  Future<void> _loadDeviceCalendarState() async {
    final enabled = await DeviceCalendarService().isEnabled();
    if (mounted) setState(() => _deviceCalendarConnected = enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).refreshUser();
    }
  }

  Color _parseUserColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.accent;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final avatarColor =
        user != null ? _parseUserColor(user.color) : AppTheme.accent;
    final initials = user != null ? _initials(user.name) : '?';
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        24;

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // Cap height so the sheet never tries to grow off-screen (e.g. on macOS
      // when the calendars section is expanded). SingleChildScrollView handles
      // the rest so nothing is clipped.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Grabber ────────────────────────────────────────────────────
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

          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Settings',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.appColors.line, width: 1),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: context.appColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Account tile ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.line, width: 1),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: avatarColor.withOpacity(0.35), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: context.appColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Email verification (only when not verified) ───────────────────
          if (user?.emailVerified == false) ...[
            _SheetSection(label: 'ACCOUNT'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8A020), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      color: Color(0xFFB07000), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Email not verified',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7A4C00),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _resending
                        ? null
                        : () async {
                            setState(() => _resending = true);
                            await ref
                                .read(authProvider.notifier)
                                .resendVerification();
                            if (!mounted) return;
                            setState(() => _resending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Verification email sent!')),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8A020),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _resending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Resend',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Notifications ─────────────────────────────────────────────────
          _SheetSection(label: 'NOTIFICATIONS'),
          const SizedBox(height: 12),
          NotificationTypeSelector(
            value: user?.notificationType ?? NotificationType.email,
            onChanged: (type) async {
              if (type == NotificationType.push) {
                await LocalNotificationService().requestPermission();
              }
              await ref
                  .read(authProvider.notifier)
                  .updateNotificationType(type);
            },
          ),
          const SizedBox(height: 20),

          // ── Connected calendars ───────────────────────────────────────────
          _SheetSection(label: 'CALENDARS'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: context.appColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appColors.line, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _calendarsExpanded = !_calendarsExpanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        AppImages.calendar(size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Connected calendars',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.ink,
                            ),
                          ),
                        ),
                        // count badge
                        Builder(builder: (_) {
                          final count =
                              (user?.hasGoogleCalendar == true ? 1 : 0) +
                                  (_deviceCalendarConnected ? 1 : 0);
                          final connected = count > 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: connected
                                  ? const Color(0xFFC9EBD9)
                                  : context.appColors.line,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: connected
                                    ? const Color(0xFF1F5C42)
                                    : context.appColors.inkMuted,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: _calendarsExpanded ? 0.25 : 0,
                          child: Icon(Icons.chevron_right_rounded,
                              size: 18, color: context.appColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_calendarsExpanded) ...[
                  Divider(
                      color: context.appColors.line,
                      height: 1,
                      indent: 14,
                      endIndent: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (user?.hasGoogleCalendar == true)
                          Row(
                            children: [
                              AppImages.check(size: 15),
                              const SizedBox(width: 10),
                              Text(
                                'Google Calendar connected',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1F5C42),
                                ),
                              ),
                            ],
                          )
                        else
                          GestureDetector(
                            onTap: _connecting
                                ? null
                                : () async {
                                    setState(() => _connecting = true);
                                    final url = await ref
                                        .read(authProvider.notifier)
                                        .getGoogleCalendarConnectUrl();
                                    if (!mounted) return;
                                    setState(() => _connecting = false);
                                    if (url == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Could not get connect URL. Is the backend running?')),
                                      );
                                      return;
                                    }
                                    await launchUrl(Uri.parse(url),
                                        mode: LaunchMode.externalApplication);
                                  },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppTheme.accent.withOpacity(0.25),
                                    width: 1),
                              ),
                              alignment: Alignment.center,
                              child: _connecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.accent),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add_rounded,
                                            size: 16, color: AppTheme.accent),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Connect Google Calendar',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        // ── Device Calendar ───────────────────────────────
                        const SizedBox(height: 16),
                        Divider(color: context.appColors.line, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            AppImages.phone(size: 13),
                            const SizedBox(width: 6),
                            Text(
                              'DEVICE CALENDAR',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.appColors.inkMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android))
                          if (_deviceCalendarConnected)
                            Row(
                              children: [
                                AppImages.check(size: 15),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Device calendar connected',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1F5C42),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    await DeviceCalendarService().disconnect();
                                    if (mounted) {
                                      setState(
                                          () => _deviceCalendarConnected = false);
                                    }
                                  },
                                  child: Text(
                                    'Disconnect',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.danger,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            GestureDetector(
                              onTap: _connectingDevice
                                  ? null
                                  : () async {
                                      setState(
                                          () => _connectingDevice = true);
                                      final ok =
                                          await DeviceCalendarService()
                                              .connect();
                                      if (!mounted) return;
                                      setState(() {
                                        _connectingDevice = false;
                                        _deviceCalendarConnected = ok;
                                      });
                                      if (!ok) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not connect. Please grant calendar permission in Settings.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        AppTheme.accent.withOpacity(0.25),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: _connectingDevice
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.accent,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_rounded,
                                              size: 16,
                                              color: AppTheme.accent),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Connect Device Calendar',
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.accent,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            )
                        else
                          Text(
                            'Device Calendar sync is only available on iPhone and Android.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.appColors.inkMuted,
                              height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Appearance ────────────────────────────────────────────────────
          _SheetSection(label: 'APPEARANCE'),
          const SizedBox(height: 10),
          _ThemePicker(),

          const SizedBox(height: 20),

          // ── Sign out ──────────────────────────────────────────────────────
          _SheetActionRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (!mounted) return;
              context.go('/welcome');
            },
          ),
          const SizedBox(height: 8),

          // ── Delete account ────────────────────────────────────────────────
          _SheetActionRow(
            icon: Icons.person_off_outlined,
            label: 'Delete account',
            isDanger: true,
            onTap: _confirmDeleteAccount,
          ),

          const SizedBox(height: 4),
        ],
      ),
      ), // SingleChildScrollView
    ); // Container
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account, all your owned calendars, and all their data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;
    final ok = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) return;
    if (ok) {
      context.go('/welcome');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not delete account. Please try again.')),
      );
    }
  }
}

// ── Settings sheet helpers ────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.appColors.inkMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: context.appColors.line, thickness: 1)),
      ],
    );
  }
}

class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppTheme.danger : context.appColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDanger
              ? AppTheme.danger.withOpacity(0.06)
              : context.appColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isDanger ? AppTheme.danger.withOpacity(0.2) : context.appColors.line,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join calendar bottom sheet ────────────────────────────────────────────────

class _JoinCalendarSheet extends StatelessWidget {
  const _JoinCalendarSheet({required this.ctrl, required this.ref});
  final TextEditingController ctrl;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24,
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
                'Join calendar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: context.appColors.ink, letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: context.appColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'INVITE CODE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: context.appColors.inkMuted, letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: context.appColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.appColors.line, width: 1.5),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.appColors.ink, fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'AB3X7Y2Z',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: context.appColors.inkMuted, letterSpacing: 0,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                final code = ctrl.text.trim();
                Navigator.pop(context);
                final cal = await ref
                    .read(calendarProvider.notifier)
                    .joinCalendar(code);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(cal != null
                          ? 'Joined "${cal.name}"!'
                          : 'Invalid invite code.'),
                    ),
                  );
                }
              },
              child: Text(
                'Join calendar',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme picker (used in settings sheet) ─────────────────────────────────────

class _ThemePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    const options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      (ThemeMode.light,  Icons.light_mode_rounded,      'Light'),
      (ThemeMode.dark,   Icons.dark_mode_rounded,        'Dark'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.line, width: 1),
      ),
      child: Row(
        children: options.map((opt) {
          final (mode, icon, label) = opt;
          final selected = current == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setMode(mode),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: AppTheme.accent, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? AppTheme.accent
                          : context.appColors.inkMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppTheme.accent
                            : context.appColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

