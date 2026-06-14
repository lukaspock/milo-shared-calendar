import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/calendar.dart';
import '../models/member.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_theme.dart';
import 'app_image.dart';

// MembersSheet replaces MembersDialog — shown via showModalBottomSheet
class MembersSheet extends ConsumerStatefulWidget {
  final CalendarModel calendar;
  const MembersSheet({super.key, required this.calendar});

  @override
  ConsumerState<MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends ConsumerState<MembersSheet> {
  late Future<List<CalendarMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _membersFuture = ref
          .read(calendarProvider.notifier)
          .getMembers(widget.calendar.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
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

          // Header
          Row(
            children: [
              StickerTile(
                hue: hueFor(widget.calendar),
                size: 36,
                radius: 10,
                child: const Icon(
                  Icons.people_rounded,
                  size: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Members',
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
                icon: Icon(
                  Icons.close_rounded,
                  color: context.appColors.inkMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Member list
          FutureBuilder<List<CalendarMember>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.appColors.ink,
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppImages.sad(size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load members',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.appColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check your connection and try again.',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.appColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.appColors.ink,
                          side: BorderSide(
                            color: context.appColors.line,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final members = snapshot.data ?? [];
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final m = members[i];
                    final hueIndex = m.name.hashCode.abs() % stickerHues.length;
                    final hue = stickerHues[hueIndex];
                    final memberColor = _parseHexColor(m.color);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.appColors.line,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar — photo if set, otherwise colour initial
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: m.avatarUrl != null
                                ? Image.network(
                                    m.avatarUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _MemberInitialsAvatar(
                                          name: m.name,
                                          color: memberColor,
                                        ),
                                  )
                                : _MemberInitialsAvatar(
                                    name: m.name,
                                    color: memberColor,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.appColors.ink,
                                  ),
                                ),
                                Text(
                                  m.email,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: context.appColors.inkMuted,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Role chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: m.isOwner
                                  ? hue.bg
                                  : context.appColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: m.isOwner
                                    ? hue.dot
                                    : context.appColors.line,
                              ),
                            ),
                            child: Text(
                              m.isOwner ? 'Owner' : 'Member',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: m.isOwner
                                    ? hue.ink
                                    : context.appColors.inkSoft,
                              ),
                            ),
                          ),

                          // Kick button
                          if (widget.calendar.isOwner && !m.isOwner) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final ok = await ref
                                    .read(calendarProvider.notifier)
                                    .kickMember(widget.calendar.id, m.id);
                                if (ok) {
                                  _refresh();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('${m.name} removed'),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: context.appColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: context.appColors.line,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_remove_rounded,
                                  size: 14,
                                  color: AppTheme.danger,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Color _parseHexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return AppTheme.accent;
  }
}

class _MemberInitialsAvatar extends StatelessWidget {
  final String name;
  final Color color;
  const _MemberInitialsAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.15),
          offset: const Offset(0, 3),
          blurRadius: 0,
        ),
      ],
    ),
    alignment: Alignment.center,
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

// Alias kept so any old references compile
typedef MembersDialog = MembersSheet;
