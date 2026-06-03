import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/poll.dart';
import '../providers/calendar_provider.dart';
import '../providers/polls_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';

class _Slot {
  DateTime start;
  DateTime end;
  _Slot(this.start, this.end);
}

// Predefined palette for vote option colors
const _colorPalette = [
  '#28A745', // green
  '#DC3545', // red
  '#E5B130', // amber
  '#2196F3', // blue
  '#9C27B0', // purple
  '#FF5722', // deep orange
  '#00BCD4', // cyan
  '#FF9800', // orange
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

    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
    // Validate vote option labels
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
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          options: _slots
              .map((s) => PollOptionInput(start: s.start, end: s.end))
              .toList(),
          voteOptions: _voteOptions,
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

  String _fmtFull(DateTime dt) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${wd[dt.weekday - 1]}, ${mo[dt.month - 1]} ${dt.day}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
            const SizedBox(height: 16),
            Text(
              'Pick a color',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.appColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorPalette.map((hex) {
                final selected = _voteOptions[index].color == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _voteOptions[index].color = hex);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? context.appColors.ink
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: context.appColors.line, width: 1.5),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: context.appColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New poll${calendar != null ? ' in ${calendar.name}' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: AppImages.poll(size: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleCtrl,
                        autofocus: true,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.ink,
                          letterSpacing: -0.8,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Poll title',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.inkMuted,
                            letterSpacing: -0.8,
                          ),
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        validator: (v) =>
                            v != null && v.trim().isNotEmpty
                                ? null
                                : 'Title required',
                      ),

                      const SizedBox(height: 12),

                      // Description
                      Container(
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: context.appColors.line, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: context.appColors.line.withOpacity(0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          style: GoogleFonts.plusJakartaSans(
                            color: context.appColors.ink,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add notes…',
                            hintStyle: GoogleFonts.plusJakartaSans(
                                color: context.appColors.inkMuted),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                  right: 12, top: 14),
                              child: AppImages.note(size: 16),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                                minWidth: 0, minHeight: 0),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Time options header
                      Text(
                        'TIME OPTIONS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.appColors.inkMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Option cards
                      ..._slots.asMap().entries.map((entry) {
                        final i = entry.key;
                        final slot = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SlotCard(
                            index: i,
                            slot: slot,
                            canRemove: _slots.length > 1,
                            fmtFull: _fmtFull,
                            onPickStart: () =>
                                _pickDateTime(i, isStart: true),
                            onPickEnd: () =>
                                _pickDateTime(i, isStart: false),
                            onRemove: () =>
                                setState(() => _slots.removeAt(i)),
                          ),
                        );
                      }),

                      // Add time option button
                      if (_slots.length < 6)
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
                                  color: context.appColors.line,
                                  width: 1.5,
                                  style: BorderStyle.solid),
                            ),
                            child: Center(
                              child: Text(
                                '+ Add time option',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appColors.inkSoft,
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Vote options header
                      Text(
                        'VOTING OPTIONS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.appColors.inkMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'How members will respond to each time slot',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: context.appColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Vote option rows
                      Container(
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: context.appColors.line, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: context.appColors.line.withOpacity(0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: _voteOptions.asMap().entries.map((entry) {
                            final i = entry.key;
                            final vo = entry.value;
                            final isLast = i == _voteOptions.length - 1;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      // Color swatch
                                      GestureDetector(
                                        onTap: () => _pickVoteOptionColor(i),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: _hexToColor(vo.color),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _hexToColor(vo.color)
                                                  .withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Label input
                                      Expanded(
                                        child: TextField(
                                          onChanged: (v) => setState(
                                              () => vo.label = v),
                                          controller:
                                              TextEditingController.fromValue(
                                            TextEditingValue(
                                              text: vo.label,
                                              selection:
                                                  TextSelection.collapsed(
                                                      offset:
                                                          vo.label.length),
                                            ),
                                          ),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.appColors.ink,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Option label',
                                            hintStyle:
                                                GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              color: context.appColors.inkMuted,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      // Remove button (only if > 2 options)
                                      if (_voteOptions.length > 2)
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _voteOptions.removeAt(i)),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: context
                                                  .appColors.surfaceSoft,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      context.appColors.line,
                                                  width: 1),
                                            ),
                                            child: Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: context
                                                    .appColors.inkMuted),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    height: 1,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    color: context.appColors.line,
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                      // Add vote option button (up to 5)
                      if (_voteOptions.length < 5) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              final usedColors = _voteOptions
                                  .map((o) => o.color)
                                  .toSet();
                              final nextColor = _colorPalette.firstWhere(
                                (c) => !usedColors.contains(c),
                                orElse: () => _colorPalette[
                                    _voteOptions.length %
                                        _colorPalette.length],
                              );
                              _voteOptions.add(PollVoteOptionInput(
                                  label: '', color: nextColor));
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: context.appColors.line, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                '+ Add vote option',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.appColors.inkSoft,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Create button
                      DecoratedBox(
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
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : Text(
                                    'Create poll',
                                    style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
                          ),
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
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.index,
    required this.slot,
    required this.canRemove,
    required this.fmtFull,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  final int index;
  final _Slot slot;
  final bool canRemove;
  final String Function(DateTime) fmtFull;
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
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Option ${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.inkMuted,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: context.appColors.line, width: 1),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: context.appColors.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
          Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: context.appColors.line),
          // Start
          _TimeRow(
            icon: AppImages.calendar(size: 16),
            label: 'From',
            value: fmtFull(slot.start),
            onTap: onPickStart,
          ),
          Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: context.appColors.line),
          // End
          _TimeRow(
            icon: AppImages.flag(size: 16),
            label: 'To',
            value: fmtFull(slot.end),
            onTap: onPickEnd,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isLast = false,
  });

  final Widget icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: isLast
              ? const BorderRadius.vertical(
                  bottom: Radius.circular(16))
              : BorderRadius.zero,
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appColors.inkSoft,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appColors.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: context.appColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
