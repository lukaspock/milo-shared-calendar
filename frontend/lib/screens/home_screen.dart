import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/calendar.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(calendarProvider);
    final user = ref.watch(authProvider).user;
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: calendarsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.ink),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.line, width: 1.5),
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: AppTheme.inkMuted, size: 28),
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
              color: AppTheme.ink,
              backgroundColor: AppTheme.surface,
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
                                    color: AppTheme.inkMuted,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user != null
                                      ? 'Hey, ${user.name.split(' ').first} 👋'
                                      : 'Your calendars',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CircleButton(
                            icon: Icons.refresh_rounded,
                            onTap: () => ref.read(calendarProvider.notifier).fetch(),
                          ),
                          const SizedBox(width: 8),
                          _CircleButton(
                            icon: Icons.person_off_outlined,
                            onTap: () => _confirmDeleteAccount(context, ref),
                          ),
                          const SizedBox(width: 8),
                          _CircleButton(
                            icon: Icons.logout_rounded,
                            onTap: () async {
                              await ref.read(authProvider.notifier).logout();
                              if (context.mounted) context.go('/login');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Email verification banner ─────────────────────────────
                  if (user != null && !user.emailVerified)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _VerificationBanner(
                          onResend: () async {
                            final ok = await ref.read(authProvider.notifier).resendVerification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(ok
                                    ? 'Verification email sent!'
                                    : 'Could not send email. Try again.'),
                              ));
                            }
                          },
                        ),
                      ),
                    ),

                  // ── Google Calendar connect banner ────────────────────────
                  if (user != null && !user.hasGoogleCalendar) ...[
                    const SliverToBoxAdapter(child: _CalendarResumeRefresher()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _GoogleCalendarBanner(
                          onConnect: () async {
                            final url = await ref
                                .read(authProvider.notifier)
                                .getGoogleCalendarConnectUrl();
                            if (!context.mounted) return;
                            if (url == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not get connect URL. Is backend deployed?')),
                              );
                              return;
                            }
                            final launched = await launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication);
                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open browser.')),
                              );
                            }
                          },
                          onCancel: () => ref.read(authProvider.notifier).refreshUser(),
                        ),
                      ),
                    ),
                  ],

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

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
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
    if (confirmed == true) {
      final ok = await ref.read(authProvider.notifier).deleteAccount();
      if (context.mounted) {
        if (ok) {
          context.go('/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete account. Please try again.')),
          );
        }
      }
    }
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: hue.bg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: hue.deep.withOpacity(0.13),
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
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: hue.deep.withOpacity(0.08),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('📅', style: TextStyle(fontSize: 22)),
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
                      color: hue.ink,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calendars.isEmpty ? 'No calendars yet' : 'Open ${calendars.first.name}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: hue.ink,
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
                      color: hue.dot,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: hue.ink, size: 20),
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
            color: AppTheme.inkMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line, width: 1),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppTheme.line, thickness: 1)),
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.line.withOpacity(0.6),
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
              child: const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.black54),
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
                      color: AppTheme.ink,
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
                            color: AppTheme.inkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Role chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: hue.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.calendar.isOwner ? 'Owner' : 'Member',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hue.ink,
                          ),
                        ),
                      ),
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
                        color: AppTheme.inkMuted,
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
              const Icon(Icons.chevron_right_rounded, color: AppTheme.inkMuted, size: 20),
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
              border: Border.all(color: AppTheme.surface, width: 2),
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.line.withOpacity(0.5),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: AppTheme.ink),
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
    final bg = isSecondary ? AppTheme.surface : AppTheme.ink;
    final fg = isSecondary ? AppTheme.ink : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: isSecondary ? Border.all(color: AppTheme.line, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: isSecondary
                  ? AppTheme.line.withOpacity(0.5)
                  : const Color(0x551F1B16),
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

// ── Email verification banner ─────────────────────────────────────────────────

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.onResend});
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5B130), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✉️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify your email',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Check your inbox and click the link to verify your address.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppTheme.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onResend,
                      child: Text(
                        'Resend email',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFFE5B130),
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFE5B130),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
              child: const Text('📅', style: TextStyle(fontSize: 34)),
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
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
                color: AppTheme.line,
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
                  color: AppTheme.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppTheme.inkMuted),
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
              child: const Text('📅', style: TextStyle(fontSize: 38)),
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
                    color: AppTheme.inkMuted, letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.line, width: 1.5),
                ),
                child: TextField(
                  controller: widget.ctrl,
                  autofocus: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.ink, fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Family, Work, Friends…',
                    hintStyle: GoogleFonts.plusJakartaSans(color: AppTheme.inkMuted),
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
              color: AppTheme.inkMuted, letterSpacing: 0.9,
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
                        color: selected ? AppTheme.ink : Colors.transparent,
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
                    side: const BorderSide(color: AppTheme.line, width: 1.5),
                    foregroundColor: AppTheme.ink,
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

// ── Join calendar bottom sheet ────────────────────────────────────────────────

class _JoinCalendarSheet extends StatelessWidget {
  const _JoinCalendarSheet({required this.ctrl, required this.ref});
  final TextEditingController ctrl;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
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
                color: AppTheme.line,
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
                  color: AppTheme.ink, letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppTheme.inkMuted),
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
                    color: AppTheme.inkMuted, letterSpacing: 0.9,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.line, width: 1.5),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.ink, fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'AB3X7Y2Z',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.inkMuted, letterSpacing: 0,
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

// Invisible widget — listens for app resume and refreshes user to detect Calendar connection
class _CalendarResumeRefresher extends ConsumerStatefulWidget {
  const _CalendarResumeRefresher();

  @override
  ConsumerState<_CalendarResumeRefresher> createState() => _CalendarResumeRefresherState();
}

class _CalendarResumeRefresherState extends ConsumerState<_CalendarResumeRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _GoogleCalendarBanner extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onCancel;

  const _GoogleCalendarBanner({required this.onConnect, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.3), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 0)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Google Calendar',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink,
                  ),
                ),
                Text(
                  'Sync your events automatically',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onConnect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Connect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.line, width: 1.5),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
