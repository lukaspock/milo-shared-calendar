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

          // Header
          Row(
            children: [
              StickerTile(
                hue: hueFor(widget.calendar),
                size: 36,
                radius: 10,
                child: const Icon(Icons.people_rounded, size: 16, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              Text(
                'Members',
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

          // Member list
          FutureBuilder<List<CalendarMember>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.ink)),
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
                          color: AppTheme.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check your connection and try again.',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.ink,
                          side: const BorderSide(color: AppTheme.line, width: 1.5),
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

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.line, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 40,
                            height: 40,
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
                            alignment: Alignment.center,
                            child: Text(
                              m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: hue.ink,
                              ),
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
                                    color: AppTheme.ink,
                                  ),
                                ),
                                Text(
                                  m.email,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppTheme.inkMuted,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: m.isOwner ? hue.bg : AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: m.isOwner ? hue.dot : AppTheme.line,
                              ),
                            ),
                            child: Text(
                              m.isOwner ? 'Owner' : 'Member',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: m.isOwner ? hue.ink : AppTheme.inkSoft,
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
                                      SnackBar(content: Text('${m.name} removed')),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.line),
                                ),
                                child: const Icon(Icons.person_remove_rounded,
                                    size: 14, color: AppTheme.danger),
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

// Alias kept so any old references compile
typedef MembersDialog = MembersSheet;
