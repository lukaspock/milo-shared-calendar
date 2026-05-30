import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/event.dart';
import '../providers/calendar_provider.dart';
import '../providers/events_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String calendarId;
  final String eventId;
  final Object? extra;

  const EventDetailScreen({
    super.key,
    required this.calendarId,
    required this.eventId,
    this.extra,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  bool _isLoading = false;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  DateTime? _recurrenceEnd;

  bool get _isNew => widget.eventId == 'new';
  CalendarEvent? get _existingEvent =>
      widget.extra is CalendarEvent ? widget.extra as CalendarEvent : null;

  @override
  void initState() {
    super.initState();
    if (_existingEvent != null) {
      _titleCtrl.text = _existingEvent!.title;
      _descCtrl.text = _existingEvent!.description ?? '';
      _startTime = _existingEvent!.startTime;
      _endTime = _existingEvent!.endTime;
      _recurrenceRule = _existingEvent!.recurrenceRule;
      _recurrenceEnd = _existingEvent!.recurrenceEnd;
    } else if (widget.extra is DateTime) {
      final d = widget.extra as DateTime;
      _startTime = DateTime(d.year, d.month, d.day, 9, 0);
      _endTime = DateTime(d.year, d.month, d.day, 10, 0);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.ink,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
            onSurface: AppTheme.ink,
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
          colorScheme: const ColorScheme.light(
            primary: AppTheme.ink,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
            onSurface: AppTheme.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = dt;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endTime.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final notifier = ref.read(eventsProvider(widget.calendarId).notifier);
    bool ok;

    if (_isNew) {
      final ev = await notifier.createEvent(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        recurrenceRule: _recurrenceRule,
        recurrenceEnd: _recurrenceEnd,
      );
      ok = ev != null;
    } else {
      ok = await notifier.updateEvent(
        _existingEvent!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        recurrenceRule: _recurrenceRule,
        clearRecurrence: _recurrenceRule == RecurrenceRule.none,
        recurrenceEnd: _recurrenceEnd,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      context.go('/calendar/${widget.calendarId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save event. Try again.')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    final ok = await ref
        .read(eventsProvider(widget.calendarId).notifier)
        .deleteEvent(_existingEvent!.id);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) context.go('/calendar/${widget.calendarId}');
  }

  Future<void> _notifyMembers() async {
    if (_existingEvent == null) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(eventsProvider(widget.calendarId).notifier)
          .notifyMembers(widget.calendarId, _existingEvent!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Members notified!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to notify members.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickRecurrence() async {
    final chosen = await showModalBottomSheet<RecurrenceRule>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Repeat', style: GoogleFonts.plusJakartaSans(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            const SizedBox(height: 12),
            for (final rule in RecurrenceRule.values)
              ListTile(
                title: Text(rule.label, style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w500,
                  color: _recurrenceRule == rule ? AppTheme.accent : AppTheme.ink)),
                trailing: _recurrenceRule == rule
                    ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                    : null,
                onTap: () => Navigator.pop(context, rule),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _recurrenceRule = chosen;
        if (chosen == RecurrenceRule.none) _recurrenceEnd = null;
      });
    }
  }

  Future<void> _pickRecurrenceEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceEnd ?? _startTime.add(const Duration(days: 30)),
      firstDate: _startTime.add(const Duration(days: 1)),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.ink, onPrimary: Colors.white,
            surface: AppTheme.surface, onSurface: AppTheme.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) setState(() => _recurrenceEnd = date);
  }

  String _fmtFull(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                    onTap: () => context.go('/calendar/${widget.calendarId}'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.line, width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppTheme.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isNew
                          ? 'New event${calendar != null ? ' in ${calendar.name}' : ''}'
                          : 'Edit event',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isNew)
                    GestureDetector(
                      onTap: _isLoading ? null : _delete,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.line, width: 1.5),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppTheme.danger),
                      ),
                    ),
                  const SizedBox(width: 8),
                  StickerTile(
                    hue: calHue,
                    size: 40,
                    radius: 12,
                    child: const Icon(Icons.calendar_today_rounded,
                        size: 18, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Scrollable form ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Huge title input
                      TextFormField(
                        controller: _titleCtrl,
                        autofocus: _isNew,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                          letterSpacing: -0.8,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Event title',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkMuted,
                            letterSpacing: -0.8,
                          ),
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        validator: (v) =>
                            v != null && v.trim().isNotEmpty ? null : 'Title required',
                      ),

                      const SizedBox(height: 20),

                      // Field card
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(22),
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
                          children: [
                            _FieldRow(
                              icon: AppImages.calendar(size: 16),
                              label: 'When',
                              value: _fmtFull(_startTime),
                              onTap: () => _pickDateTime(isStart: true),
                              isFirst: true,
                            ),
                            _Divider(),
                            _FieldRow(
                              icon: AppImages.flag(size: 16),
                              label: 'Ends',
                              value: _fmtFull(_endTime),
                              onTap: () => _pickDateTime(isStart: false),
                            ),
                            _Divider(),
                            _FieldRow(
                              icon: const Icon(Icons.repeat_rounded,
                                  size: 16, color: AppTheme.inkSoft),
                              label: 'Repeat',
                              value: _recurrenceRule.label,
                              onTap: _pickRecurrence,
                              isLast: _recurrenceRule == RecurrenceRule.none,
                            ),
                            if (_recurrenceRule != RecurrenceRule.none) ...[
                              _Divider(),
                              _FieldRow(
                                icon: const Icon(Icons.event_outlined,
                                    size: 16, color: AppTheme.inkSoft),
                                label: 'Repeat until',
                                value: _recurrenceEnd != null
                                    ? '${_recurrenceEnd!.year}-'
                                      '${_recurrenceEnd!.month.toString().padLeft(2, '0')}-'
                                      '${_recurrenceEnd!.day.toString().padLeft(2, '0')}'
                                    : 'No end date',
                                onTap: _pickRecurrenceEnd,
                                isLast: true,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Notes card
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.line, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.line.withOpacity(0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextFormField(
                          controller: _descCtrl,
                          maxLines: 4,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add notes…',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: AppTheme.inkMuted,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12, top: 14),
                              child: AppImages.note(size: 16),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0, minHeight: 0,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Save button
                      DecoratedBox(
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
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isNew ? 'Save event' : 'Save changes',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700, fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // Notify members button (existing events only)
                      if (!_isNew) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
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
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _notifyMembers,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.ink,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              icon: AppImages.bell(size: 16),
                              label: Text(
                                'Notify members',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final Widget icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
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
                color: AppTheme.inkSoft,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppTheme.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.line,
    );
  }
}
