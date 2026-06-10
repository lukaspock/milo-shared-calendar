import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as epf;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/poll.dart';
import '../providers/calendar_provider.dart';
import '../providers/polls_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class _Slot {
  DateTime start;
  DateTime end;
  _Slot(this.start, this.end);
}

const _colorPalette = [
  '#28A745', '#DC3545', '#E5B130', '#2196F3',
  '#9C27B0', '#FF5722', '#00BCD4', '#FF9800',
];

class CreatePollScreen extends ConsumerStatefulWidget {
  final String calendarId;
  const CreatePollScreen({super.key, required this.calendarId});

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  String? _selectedIcon;

  final List<_Slot> _slots = [];
  final List<PollVoteOptionInput> _voteOptions = [
    PollVoteOptionInput(label: 'Going', color: '#28A745'),
    PollVoteOptionInput(label: 'Not going', color: '#DC3545'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day + 1, 10, 0);
    _slots.add(_Slot(base, base.add(const Duration(hours: 1))));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(int index, {required bool isStart}) async {
    final slot = _slots[index];
    final initial = isStart ? slot.start : slot.end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: context.appColors.ink,
            onPrimary: Colors.white,
            surface: context.appColors.surface,
            onSurface: context.appColors.ink,
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
            primary: context.appColors.ink,
            onPrimary: Colors.white,
            surface: context.appColors.surface,
            onSurface: context.appColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        slot.start = dt;
        if (slot.end.isBefore(slot.start)) {
          slot.end = slot.start.add(const Duration(hours: 1));
        }
      } else {
        if (dt.isAfter(slot.start)) slot.end = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    for (final vo in _voteOptions) {
      if (vo.label.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All vote options need a label.')),
        );
        return;
      }
    }
    setState(() => _isLoading = true);
    final poll = await ref
        .read(pollsProvider(widget.calendarId).notifier)
        .createPoll(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          options: _slots.map((s) => PollOptionInput(start: s.start, end: s.end)).toList(),
          voteOptions: _voteOptions,
          icon: _selectedIcon,
          color: null,
        );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (poll != null) {
      context.go('/calendar/${widget.calendarId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create poll. Try again.')),
      );
    }
  }

  String _fmtDate(DateTime dt) {
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${mo[dt.month - 1]} ${dt.day}';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _pickVoteOptionColor(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: context.appColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pick a color',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: context.appColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14, runSpacing: 14,
              children: _colorPalette.map((hex) {
                final selected = _voteOptions[index].color == hex;
                final color = _hexToColor(hex);
                return GestureDetector(
                  onTap: () {
                    setState(() => _voteOptions[index].color = hex);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? context.appColors.ink : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    onTap: () => context.go('/calendar/${widget.calendarId}'),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.appColors.line, width: 1.5),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: context.appColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New poll',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: context.appColors.ink,
                      ),
                    ),
                  ),
                  // Save button in header
                  GestureDetector(
                    onTap: _isLoading ? null : _save,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: calHue.deep,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Create',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title ─────────────────────────────────────────────
                      TextFormField(
                        controller: _titleCtrl,
                        autofocus: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30, fontWeight: FontWeight.w700,
                          color: context.appColors.ink, letterSpacing: -0.8,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Poll title',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 30, fontWeight: FontWeight.w700,
                            color: context.appColors.inkMuted, letterSpacing: -0.8,
                          ),
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        validator: (v) =>
                            v != null && v.trim().isNotEmpty ? null : 'Title required',
                      ),

                      const SizedBox(height: 6),

                      // ── Description + Icon inline card ────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.appColors.line, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: context.appColors.line.withOpacity(0.5),
                              offset: const Offset(0, 4), blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Notes row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              child: TextFormField(
                                controller: _descCtrl,
                                maxLines: 2,
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.appColors.ink, fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add a note…',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                      color: context.appColors.inkMuted, fontSize: 14),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 12, top: 16),
                                    child: Icon(Icons.notes_rounded,
                                        size: 16, color: context.appColors.inkMuted),
                                  ),
                                  prefixIconConstraints:
                                      const BoxConstraints(minWidth: 0, minHeight: 0),
                                ),
                              ),
                            ),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              color: context.appColors.line,
                            ),
                            // Icon row
                            GestureDetector(
                              onTap: () async {
                                final picked = await showModalBottomSheet<String>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => _PollIconPickerSheet(
                                    current: _selectedIcon,
                                    surfaceColor: context.appColors.surface,
                                    lineColor: context.appColors.line,
                                    inkColor: context.appColors.ink,
                                    inkMutedColor: context.appColors.inkMuted,
                                    surfaceSoftColor: context.appColors.surfaceSoft,
                                  ),
                                );
                                if (picked != null && mounted) {
                                  setState(() => _selectedIcon = picked);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: _selectedIcon != null
                                            ? calHue.bg
                                            : context.appColors.surfaceSoft,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: context.appColors.line, width: 1.5),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _selectedIcon != null &&
                                                _selectedIcon!.startsWith('http')
                                            ? Image.network(_selectedIcon!,
                                                width: 36, height: 36, fit: BoxFit.cover)
                                            : Center(
                                                child: Text(
                                                  _selectedIcon ?? '✨',
                                                  style: TextStyle(
                                                    fontSize: _selectedIcon != null ? 20 : 16,
                                                    color: _selectedIcon != null
                                                        ? null
                                                        : context.appColors.inkMuted,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedIcon != null ? 'Event icon' : 'Add icon',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14, fontWeight: FontWeight.w600,
                                              color: context.appColors.ink,
                                            ),
                                          ),
                                          Text(
                                            'Shown when poll is confirmed',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11, color: context.appColors.inkMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_selectedIcon != null)
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedIcon = null),
                                        child: Icon(Icons.close_rounded,
                                            size: 16, color: context.appColors.inkMuted),
                                      )
                                    else
                                      Icon(Icons.chevron_right_rounded,
                                          size: 16, color: context.appColors.inkMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Time options ───────────────────────────────────────
                      _SectionLabel(label: 'TIME OPTIONS'),
                      const SizedBox(height: 10),

                      ..._slots.asMap().entries.map((entry) {
                        final i = entry.key;
                        final slot = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SlotCard(
                            index: i,
                            slot: slot,
                            canRemove: _slots.length > 1,
                            accentColor: calHue.deep,
                            accentBg: calHue.bg,
                            fmtDate: _fmtDate,
                            fmtTime: _fmtTime,
                            onPickStart: () => _pickDateTime(i, isStart: true),
                            onPickEnd: () => _pickDateTime(i, isStart: false),
                            onRemove: () => setState(() => _slots.removeAt(i)),
                          ),
                        );
                      }),

                      if (_slots.length < 8)
                        GestureDetector(
                          onTap: () {
                            final last = _slots.last;
                            setState(() {
                              _slots.add(_Slot(
                                last.start.add(const Duration(days: 1)),
                                last.end.add(const Duration(days: 1)),
                              ));
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: context.appColors.line, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline_rounded,
                                    size: 16, color: calHue.deep),
                                const SizedBox(width: 6),
                                Text(
                                  'Add time option',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: calHue.deep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 28),

                      // ── Voting options ─────────────────────────────────────
                      _SectionLabel(label: 'HOW MEMBERS RESPOND'),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          ..._voteOptions.asMap().entries.map((entry) {
                            final i = entry.key;
                            final vo = entry.value;
                            return _VoteOptionChip(
                              voteOption: vo,
                              canRemove: _voteOptions.length > 2,
                              hexToColor: _hexToColor,
                              onEditLabel: (newLabel) =>
                                  setState(() => vo.label = newLabel),
                              onPickColor: () => _pickVoteOptionColor(i),
                              onRemove: () => setState(() => _voteOptions.removeAt(i)),
                            );
                          }),
                          if (_voteOptions.length < 5)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  final usedColors = _voteOptions.map((o) => o.color).toSet();
                                  final nextColor = _colorPalette.firstWhere(
                                    (c) => !usedColors.contains(c),
                                    orElse: () =>
                                        _colorPalette[_voteOptions.length % _colorPalette.length],
                                  );
                                  _voteOptions.add(
                                      PollVoteOptionInput(label: '', color: nextColor));
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: context.appColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: context.appColors.line, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 14, color: context.appColors.inkSoft),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Add option',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: context.appColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: context.appColors.inkMuted, letterSpacing: 0.9,
        ),
      );
}

// ── Slot card ─────────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.index,
    required this.slot,
    required this.canRemove,
    required this.accentColor,
    required this.accentBg,
    required this.fmtDate,
    required this.fmtTime,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  final int index;
  final _Slot slot;
  final bool canRemove;
  final Color accentColor;
  final Color accentBg;
  final String Function(DateTime) fmtDate;
  final String Function(DateTime) fmtTime;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appColors.line, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.appColors.line.withOpacity(0.5),
            offset: const Offset(0, 4), blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Numbered badge on left
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w800, color: accentColor,
                  ),
                ),
              ),
            ),
          ),
          // Start + end rows
          Expanded(
            child: Column(
              children: [
                GestureDetector(
                  onTap: onPickStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'START',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: context.appColors.inkMuted, letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtDate(slot.start)}  ${fmtTime(slot.start)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: context.appColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_calendar_outlined,
                            size: 15, color: context.appColors.inkMuted),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(right: 16),
                  color: context.appColors.line,
                ),
                GestureDetector(
                  onTap: onPickEnd,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'END',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: context.appColors.inkMuted, letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtDate(slot.end)}  ${fmtTime(slot.end)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: context.appColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.edit_calendar_outlined,
                            size: 15, color: context.appColors.inkMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          if (canRemove)
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.appColors.line, width: 1),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: context.appColors.inkMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Vote option chip (editable inline) ───────────────────────────────────────

class _VoteOptionChip extends StatefulWidget {
  const _VoteOptionChip({
    required this.voteOption,
    required this.canRemove,
    required this.hexToColor,
    required this.onEditLabel,
    required this.onPickColor,
    required this.onRemove,
  });

  final PollVoteOptionInput voteOption;
  final bool canRemove;
  final Color Function(String) hexToColor;
  final void Function(String) onEditLabel;
  final VoidCallback onPickColor;
  final VoidCallback onRemove;

  @override
  State<_VoteOptionChip> createState() => _VoteOptionChipState();
}

class _VoteOptionChipState extends State<_VoteOptionChip> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.voteOption.label);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.hexToColor(widget.voteOption.color);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onPickColor,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, size: 11, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          IntrinsicWidth(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onEditLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: color,
              ),
              decoration: InputDecoration(
                hintText: 'Label',
                hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: color.withOpacity(0.5)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.canRemove) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onRemove,
              child: Icon(Icons.close_rounded, size: 13, color: color.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Poll icon picker ──────────────────────────────────────────────────────────

const _pollPresetIcons = [
  '📅', '🗓️', '🏠', '💼', '🎓', '🏋️', '✈️', '🎵',
  '👨‍👩‍👧', '🎉', '⚽', '🍕', '🌿', '📚', '🤝', '🏖️',
  '🎨', '💡', '🎤', '🌟', '🎮', '🐾', '🍳', '❤️',
];

class _PollModeTab extends StatelessWidget {
  const _PollModeTab({
    required this.label,
    required this.active,
    required this.inkColor,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color inkColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? inkColor : inkColor.withOpacity(0.4),
          ),
        ),
      );
}

class _PollIconPickerSheet extends StatefulWidget {
  const _PollIconPickerSheet({
    required this.current,
    required this.surfaceColor,
    required this.lineColor,
    required this.inkColor,
    required this.inkMutedColor,
    required this.surfaceSoftColor,
  });
  final String? current;
  final Color surfaceColor;
  final Color lineColor;
  final Color inkColor;
  final Color inkMutedColor;
  final Color surfaceSoftColor;

  @override
  State<_PollIconPickerSheet> createState() => _PollIconPickerSheetState();
}

class _PollIconPickerSheetState extends State<_PollIconPickerSheet> {
  String _mode = 'presets';
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256, maxHeight: 256, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ApiService().uploadEventIconToCloudinary(picked);
      if (mounted) {
        setState(() => _uploading = false);
        Navigator.pop(context, url);
      }
    } on CloudinaryUploadException catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: widget.lineColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('Event icon',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: widget.inkColor)),
            const Spacer(),
            _PollModeTab(label: 'Presets', active: _mode == 'presets',
                inkColor: widget.inkColor, onTap: () => setState(() => _mode = 'presets')),
            const SizedBox(width: 10),
            _PollModeTab(label: 'Emoji', active: _mode == 'emoji',
                inkColor: widget.inkColor, onTap: () => setState(() => _mode = 'emoji')),
            const SizedBox(width: 10),
            _PollModeTab(label: 'Photo', active: _mode == 'photo',
                inkColor: widget.inkColor, onTap: () => setState(() => _mode = 'photo')),
          ]),
          const SizedBox(height: 16),
          if (_mode == 'presets')
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _pollPresetIcons.map((e) {
                final selected = e == widget.current;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.inkColor.withOpacity(0.1)
                          : widget.surfaceSoftColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? widget.inkColor.withOpacity(0.5)
                            : widget.lineColor,
                        width: selected ? 2 : 1.5,
                      ),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
                  ),
                );
              }).toList(),
            )
          else if (_mode == 'emoji')
            SizedBox(
              height: 320,
              child: epf.EmojiPicker(
                onEmojiSelected: (_, emoji) => Navigator.pop(context, emoji.emoji),
                config: epf.Config(
                  emojiViewConfig: epf.EmojiViewConfig(
                      backgroundColor: widget.surfaceColor, emojiSizeMax: 28),
                  searchViewConfig: epf.SearchViewConfig(
                      backgroundColor: widget.surfaceColor,
                      buttonIconColor: widget.inkColor),
                  categoryViewConfig: epf.CategoryViewConfig(
                      backgroundColor: widget.surfaceColor,
                      iconColor: widget.inkColor.withOpacity(0.4),
                      iconColorSelected: widget.inkColor,
                      indicatorColor: widget.inkColor),
                  bottomActionBarConfig: const epf.BottomActionBarConfig(enabled: false),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _uploading ? null : _pickPhoto,
              child: Container(
                width: double.infinity, height: 120,
                decoration: BoxDecoration(
                  color: widget.surfaceSoftColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.lineColor, width: 1.5),
                ),
                child: _uploading
                    ? Center(child: CircularProgressIndicator(
                        color: widget.inkColor, strokeWidth: 2))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 32, color: widget.inkMutedColor),
                          const SizedBox(height: 8),
                          Text('Pick from gallery',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  color: widget.inkMutedColor)),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
