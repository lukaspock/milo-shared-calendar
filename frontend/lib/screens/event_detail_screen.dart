import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as epf;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart' show CalendarEvent, EventSource, RecurrenceRule;
import '../models/reaction.dart';
import '../models/rsvp.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/events_provider.dart';
import '../services/api_service.dart';
import '../services/local_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_image.dart';

bool _isEventIconUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

// Common emoji options for quick reactions
const _quickEmojis = ['❤️', '🎉', '👍', '😂', '🔥', '😮', '👏', '🙌'];

// Premade event icon options
const _premadeIcons = [
  '📅',
  '🎂',
  '✈️',
  '🏋️',
  '🎮',
  '🎵',
  '🎓',
  '💼',
  '🏖️',
  '🍕',
  '🎉',
  '⚽',
  '🏥',
  '🛒',
  '📚',
  '🎨',
  '🤝',
  '💡',
  '🎤',
  '🌿',
];

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

// Reminder options shown in the event form: null = no reminder.
const _kReminderOptions = [null, 5, 15, 30, 60, 120, 1440];

String _reminderLabel(int? minutes) {
  if (minutes == null) return 'None';
  if (minutes < 60) return '$minutes min';
  if (minutes == 60) return '1 hour';
  if (minutes < 1440) return '${minutes ~/ 60} hours';
  return '1 day';
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
  String? _selectedIcon;
  // Reminder lead time: null = no reminder, int = minutes before event.
  int? _reminderMinutes = 30;

  List<EventReaction> _reactions = [];
  bool _reactionsLoading = false;

  EventRsvpDetail _rsvpDetail = const EventRsvpDetail.empty();
  bool _rsvpLoading = false;

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
      _selectedIcon = _existingEvent!.icon;
      _loadReactions();
      _loadRsvpDetail();
      _loadSavedReminder();
    } else if (widget.extra is DateTime) {
      final d = widget.extra as DateTime;
      _startTime = DateTime(d.year, d.month, d.day, 9, 0);
      _endTime = DateTime(d.year, d.month, d.day, 10, 0);
    }
  }

  Future<void> _loadSavedReminder() async {
    if (_existingEvent == null) return;
    final saved = await LocalNotificationService().loadReminderPreference(
      _existingEvent!.id,
    );
    // loadReminderPreference returns null if no key is stored.
    // We distinguish "not stored yet" (use default 30) from "stored as null"
    // (user explicitly chose no reminder). SharedPreferences.getInt returns
    // null for a missing key, so we keep the default 30 if nothing is saved.
    if (saved != null && mounted) setState(() => _reminderMinutes = saved);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReactions() async {
    if (_isNew) return;
    // Reactions are only supported for native SharedCal events
    if (_existingEvent?.source != null &&
        _existingEvent!.source != EventSource.sharedcal) {
      return;
    }
    if (!mounted) return;
    setState(() => _reactionsLoading = true);
    try {
      final list = await ApiService().fetchReactions(widget.eventId);
      if (mounted) setState(() => _reactions = list);
    } catch (_) {}
    if (mounted) setState(() => _reactionsLoading = false);
  }

  Future<void> _loadRsvpDetail() async {
    if (_existingEvent?.source != EventSource.sharedcal) return;
    if (!mounted) return;
    setState(() => _rsvpLoading = true);
    try {
      final detail = await ApiService().getRsvpDetail(widget.eventId);
      if (mounted) setState(() => _rsvpDetail = detail);
    } catch (_) {}
    if (mounted) setState(() => _rsvpLoading = false);
  }

  Future<void> _setRsvp(String status) async {
    try {
      final updated = _rsvpDetail.myStatus == status
          ? await ApiService().deleteRsvp(widget.eventId)
          : await ApiService().setRsvp(widget.eventId, status);
      if (mounted) setState(() => _rsvpDetail = updated);
    } catch (_) {}
  }

  Future<void> _addReaction(String emoji) async {
    try {
      final list = await ApiService().addReaction(widget.eventId, emoji);
      if (mounted) setState(() => _reactions = list);
    } catch (_) {}
  }

  Future<void> _removeReaction(String emoji) async {
    try {
      await ApiService().removeReaction(widget.eventId, emoji);
      await _loadReactions();
    } catch (_) {}
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

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        icon: _selectedIcon,
        recurrenceRule: _recurrenceRule,
        recurrenceEnd: _recurrenceEnd,
        reminderMinutes: _reminderMinutes,
      );
      ok = ev != null;
    } else {
      bool editAll = false;
      if (_existingEvent!.isRecurring || _existingEvent!.isRecurringInstance) {
        if (!mounted) return;
        final choice = await _showSeriesDialog(
          title: 'Edit recurring event',
          singleLabel: 'Edit this event only',
          allLabel: 'Edit all future events',
        );
        if (choice == null || !mounted) {
          setState(() => _isLoading = false);
          return;
        }
        editAll = choice;
      }
      ok = await notifier.updateEvent(
        _existingEvent!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        icon: _selectedIcon,
        recurrenceRule: _recurrenceRule,
        clearRecurrence: _recurrenceRule == RecurrenceRule.none,
        recurrenceEnd: _recurrenceEnd,
        editAll: editAll,
        reminderMinutes: _reminderMinutes,
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

  Future<bool?> _showSeriesDialog({
    required String title,
    required String singleLabel,
    required String allLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: const Text('This event is part of a recurring series.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(singleLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(allLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    bool deleteAll = false;

    if (_existingEvent!.isRecurring || _existingEvent!.isRecurringInstance) {
      final choice = await _showSeriesDialog(
        title: 'Delete recurring event',
        singleLabel: 'Delete this event',
        allLabel: 'Delete all in series',
      );
      if (choice == null || !mounted) return;
      deleteAll = choice;
    } else {
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
    }

    setState(() => _isLoading = true);
    final ok = await ref
        .read(eventsProvider(widget.calendarId).notifier)
        .deleteEvent(_existingEvent!.id, deleteAll: deleteAll);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) context.go('/calendar/${widget.calendarId}');
  }

  Future<void> _pickRecurrence() async {
    final chosen = await showModalBottomSheet<RecurrenceRule>(
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Repeat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.appColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            for (final rule in RecurrenceRule.values)
              ListTile(
                title: Text(
                  rule.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _recurrenceRule == rule
                        ? AppTheme.accent
                        : context.appColors.ink,
                  ),
                ),
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
    if (date != null && mounted) setState(() => _recurrenceEnd = date);
  }

  String _fmtFull(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReactionPickerSheet(
        onEmojiSelected: (emoji) {
          Navigator.pop(context);
          _addReaction(emoji);
        },
        surfaceColor: context.appColors.surface,
        lineColor: context.appColors.line,
        inkColor: context.appColors.ink,
        surfaceSoftColor: context.appColors.surfaceSoft,
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IconPickerSheet(
        current: _selectedIcon,
        onSelected: (icon) {
          Navigator.pop(context);
          setState(() => _selectedIcon = icon);
        },
        surfaceColor: context.appColors.surface,
        lineColor: context.appColors.line,
        inkColor: context.appColors.ink,
        inkMutedColor: context.appColors.inkMuted,
        surfaceSoftColor: context.appColors.surfaceSoft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final currentUserId = currentUser?.id ?? '';

    final calendarsAsync = ref.watch(calendarProvider);
    final calendar = calendarsAsync.valueOrNull
        ?.where((c) => c.id == widget.calendarId)
        .firstOrNull;
    final calHue = calendar != null ? hueFor(calendar) : stickerHues[0];

    // Determine if current user can edit this event.
    // Imported events (Google Calendar, device) are always read-only.
    final isImported =
        !_isNew &&
        _existingEvent != null &&
        _existingEvent!.source != EventSource.sharedcal;
    final isCreator =
        _existingEvent != null && _existingEvent!.createdBy == currentUserId;
    final isOwner = calendar?.isOwner ?? false;
    final canEdit = _isNew || (!isImported && (isCreator || isOwner));

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
                  Expanded(
                    child: Text(
                      _isNew
                          ? 'New event${calendar != null ? ' in ${calendar.name}' : ''}'
                          : canEdit
                          ? 'Edit event'
                          : 'Event',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: canEdit
                  ? _buildEditForm(context, calHue)
                  : _buildViewMode(context, calHue, currentUserId),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit form (creator / owner / new event) ──────────────────────────────

  Widget _buildEditForm(BuildContext context, CalHue calHue) {
    return SingleChildScrollView(
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
                color: context.appColors.ink,
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
                  color: context.appColors.inkMuted,
                  letterSpacing: -0.8,
                ),
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Title required',
            ),

            const SizedBox(height: 16),

            // Icon picker row
            GestureDetector(
              onTap: _showIconPicker,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.appColors.line,
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          _selectedIcon != null &&
                              _isEventIconUrl(_selectedIcon!)
                          ? Image.network(
                              _selectedIcon!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                size: 22,
                              ),
                            )
                          : Center(
                              child: Text(
                                _selectedIcon ?? '＋',
                                style: TextStyle(
                                  fontSize: _selectedIcon != null ? 22 : 18,
                                  color: _selectedIcon != null
                                      ? null
                                      : context.appColors.inkMuted,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _selectedIcon != null ? 'Change icon' : 'Add icon',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.inkSoft,
                    ),
                  ),
                  if (_selectedIcon != null) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _selectedIcon = null),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Field card
            Container(
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(22),
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
                    icon: Icon(
                      Icons.repeat_rounded,
                      size: 16,
                      color: context.appColors.inkSoft,
                    ),
                    label: 'Repeat',
                    value: _recurrenceRule.label,
                    onTap: _pickRecurrence,
                    isLast: _recurrenceRule == RecurrenceRule.none,
                  ),
                  if (_recurrenceRule != RecurrenceRule.none) ...[
                    _Divider(),
                    _FieldRow(
                      icon: Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: context.appColors.inkSoft,
                      ),
                      label: 'Repeat until',
                      value: _recurrenceEnd != null
                          ? '${_recurrenceEnd!.year}-'
                                '${_recurrenceEnd!.month.toString().padLeft(2, '0')}-'
                                '${_recurrenceEnd!.day.toString().padLeft(2, '0')}'
                          : 'No end date',
                      onTap: _pickRecurrenceEnd,
                      isLast: false,
                    ),
                  ],
                  _Divider(),
                  _ReminderRow(
                    value: _reminderMinutes,
                    onChanged: (v) => setState(() => _reminderMinutes = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notes card
            Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                style: GoogleFonts.plusJakartaSans(
                  color: context.appColors.ink,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Add notes…',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: context.appColors.inkMuted,
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
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
              ),
            ),

            // RSVP + Reactions section (edit mode, existing events)
            if (!_isNew) ...[
              const SizedBox(height: 24),
              _RsvpSection(
                detail: _rsvpDetail,
                loading: _rsvpLoading,
                onVote: _setRsvp,
              ),
              const SizedBox(height: 24),
              _ReactionsSection(
                reactions: _reactions,
                loading: _reactionsLoading,
                currentUserId: ref.watch(authProvider).user?.id ?? '',
                onAdd: _showEmojiPicker,
                onRemove: _removeReaction,
              ),
            ],

            const SizedBox(height: 32),

            // Save button
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
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isNew ? 'Save event' : 'Save changes',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),

            // Delete button (existing events only)
            if (!_isNew) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33E85535),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _delete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      'Delete event',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── View mode (non-creator / non-owner) ──────────────────────────────────

  Widget _buildViewMode(
    BuildContext context,
    CalHue calHue,
    String currentUserId,
  ) {
    final event = _existingEvent;
    if (event == null) {
      return Center(
        child: CircularProgressIndicator(color: context.appColors.ink),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title (with optional icon)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (event.icon != null) ...[
                _EventIconDisplay(icon: event.icon!, size: 36),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  event.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.ink,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),

          if (event.creatorName != null) ...[
            const SizedBox(height: 6),
            Text(
              'by ${event.creatorName}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: context.appColors.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Attribution for imported events
          if (event.source == EventSource.googleImport) ...[
            const SizedBox(height: 4),
            Text(
              _importedByText(event),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: context.appColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (event.source == EventSource.deviceImport) ...[
            const SizedBox(height: 4),
            Text(
              'From your device calendar',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: context.appColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Time info card (read-only)
          Container(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(22),
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
                _ReadOnlyRow(
                  icon: AppImages.calendar(size: 16),
                  label: 'When',
                  value: _fmtFull(event.startTime),
                  isFirst: true,
                ),
                _Divider(),
                _ReadOnlyRow(
                  icon: AppImages.flag(size: 16),
                  label: 'Ends',
                  value: _fmtFull(event.endTime),
                  isLast: event.recurrenceRule == RecurrenceRule.none,
                ),
                if (event.recurrenceRule != RecurrenceRule.none) ...[
                  _Divider(),
                  _ReadOnlyRow(
                    icon: Icon(
                      Icons.repeat_rounded,
                      size: 16,
                      color: context.appColors.inkSoft,
                    ),
                    label: 'Repeats',
                    value: event.recurrenceRule.label,
                    isLast: true,
                  ),
                ],
              ],
            ),
          ),

          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
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
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImages.note(size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.description!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: context.appColors.ink,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // RSVP + Reactions — only for native SharedCal events
          if (event.source == EventSource.sharedcal) ...[
            const SizedBox(height: 24),
            _RsvpSection(
              detail: _rsvpDetail,
              loading: _rsvpLoading,
              onVote: _setRsvp,
            ),
            const SizedBox(height: 24),
            _ReactionsSection(
              reactions: _reactions,
              loading: _reactionsLoading,
              currentUserId: currentUserId,
              onAdd: _showEmojiPicker,
              onRemove: _removeReaction,
            ),
          ],
        ],
      ),
    );
  }

  String _importedByText(CalendarEvent event) {
    if (event.importedBy.isEmpty) return 'From Google Calendar';
    if (event.importedBy.length == 1) {
      return "From ${event.importedBy.first.name}'s Google Calendar";
    }
    final names = event.importedBy.take(2).map((u) => u.name).join(' & ');
    return "From $names's Google Calendars";
  }
}

// ── Reactions section ─────────────────────────────────────────────────────────

class _ReactionsSection extends StatelessWidget {
  const _ReactionsSection({
    required this.reactions,
    required this.loading,
    required this.currentUserId,
    required this.onAdd,
    required this.onRemove,
  });

  final List<EventReaction> reactions;
  final bool loading;
  final String currentUserId;
  final VoidCallback onAdd;
  final void Function(String emoji) onRemove;

  @override
  Widget build(BuildContext context) {
    // Group reactions by emoji
    final grouped = <String, List<EventReaction>>{};
    for (final r in reactions) {
      grouped.putIfAbsent(r.emoji, () => []).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'REACTIONS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.appColors.inkMuted,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appColors.line, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_reaction_outlined,
                      size: 14,
                      color: context.appColors.inkSoft,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'React',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (loading)
          Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.appColors.inkMuted,
              ),
            ),
          )
        else if (grouped.isEmpty)
          Text(
            'No reactions yet — be the first!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: context.appColors.inkMuted,
              fontWeight: FontWeight.w400,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: grouped.entries.map((entry) {
              final emoji = entry.key;
              final list = entry.value;
              final mine = list.any((r) => r.userId == currentUserId);
              final names = list.map((r) => r.userName).take(3).join(', ');
              final tooltip = list.length > 3
                  ? '$names and ${list.length - 3} more'
                  : names;

              return Tooltip(
                message: tooltip,
                child: GestureDetector(
                  onTap: () => mine ? onRemove(emoji) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? context.appColors.inkMuted.withOpacity(0.12)
                          : context.appColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: mine
                            ? context.appColors.ink.withOpacity(0.3)
                            : context.appColors.line,
                        width: mine ? 2 : 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '${list.length}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ── Read-only row ──────────────────────────────────────────────────────────

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  final Widget icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
      ),
    );
  }
}

// ── Field row (tappable) ───────────────────────────────────────────────────

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
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: context.appColors.inkMuted,
            ),
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
      color: context.appColors.line,
    );
  }
}

// ── Reminder row ──────────────────────────────────────────────────────────────
// Horizontal chip row for picking a reminder lead time (none / 5 / 15 / 30 / …)

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 16,
            color: context.appColors.inkSoft,
          ),
          const SizedBox(width: 12),
          Text(
            'Remind me',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appColors.inkSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _kReminderOptions.map((opt) {
                  final selected = opt == value;
                  return GestureDetector(
                    onTap: () => onChanged(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.appColors.ink
                            : context.appColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? context.appColors.ink
                              : context.appColors.line,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _reminderLabel(opt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? context.appColors.bg
                              : context.appColors.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reaction picker sheet ─────────────────────────────────────────────────────
// Shows 8 quick emojis + a "More" button that opens the full emoji keyboard.

class _ReactionPickerSheet extends StatefulWidget {
  const _ReactionPickerSheet({
    required this.onEmojiSelected,
    required this.surfaceColor,
    required this.lineColor,
    required this.inkColor,
    required this.surfaceSoftColor,
  });

  final void Function(String emoji) onEmojiSelected;
  final Color surfaceColor;
  final Color lineColor;
  final Color inkColor;
  final Color surfaceSoftColor;

  @override
  State<_ReactionPickerSheet> createState() => _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends State<_ReactionPickerSheet> {
  bool _showFull = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: _showFull ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: widget.lineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'React',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: widget.inkColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showFull = !_showFull),
                child: Text(
                  _showFull ? 'Quick picks' : 'All emojis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.inkColor.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_showFull)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickEmojis
                  .map(
                    (e) => GestureDetector(
                      onTap: () => widget.onEmojiSelected(e),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: widget.surfaceSoftColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.lineColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            Expanded(
              child: epf.EmojiPicker(
                onEmojiSelected: (_, emoji) =>
                    widget.onEmojiSelected(emoji.emoji),
                config: epf.Config(
                  emojiViewConfig: epf.EmojiViewConfig(
                    backgroundColor: widget.surfaceColor,
                    emojiSizeMax: 28,
                  ),
                  searchViewConfig: epf.SearchViewConfig(
                    backgroundColor: widget.surfaceColor,
                    buttonIconColor: widget.inkColor,
                  ),
                  categoryViewConfig: epf.CategoryViewConfig(
                    backgroundColor: widget.surfaceColor,
                    iconColor: widget.inkColor.withOpacity(0.4),
                    iconColorSelected: widget.inkColor,
                    indicatorColor: widget.inkColor,
                  ),
                  bottomActionBarConfig: const epf.BottomActionBarConfig(
                    enabled: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Icon picker sheet ─────────────────────────────────────────────────────────
// Premade emoji grid + "Custom" button → full emoji picker.

class _IconPickerSheet extends StatefulWidget {
  const _IconPickerSheet({
    required this.current,
    required this.onSelected,
    required this.surfaceColor,
    required this.lineColor,
    required this.inkColor,
    required this.inkMutedColor,
    required this.surfaceSoftColor,
  });

  final String? current;
  final void Function(String icon) onSelected;
  final Color surfaceColor;
  final Color lineColor;
  final Color inkColor;
  final Color inkMutedColor;
  final Color surfaceSoftColor;

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet> {
  // 'presets' | 'emoji' | 'photo'
  String _mode = 'presets';
  bool _uploading = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await ApiService().uploadEventIconToCloudinary(picked);
      if (mounted) {
        setState(() => _uploading = false);
        widget.onSelected(url);
      }
    } on CloudinaryUploadException catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
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
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: widget.lineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header + mode tabs
          Row(
            children: [
              Text(
                'Event icon',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: widget.inkColor,
                ),
              ),
              const Spacer(),
              _ModeTab(
                label: 'Presets',
                active: _mode == 'presets',
                inkColor: widget.inkColor,
                onTap: () => setState(() => _mode = 'presets'),
              ),
              const SizedBox(width: 10),
              _ModeTab(
                label: 'Emoji',
                active: _mode == 'emoji',
                inkColor: widget.inkColor,
                onTap: () => setState(() => _mode = 'emoji'),
              ),
              const SizedBox(width: 10),
              _ModeTab(
                label: 'Photo',
                active: _mode == 'photo',
                inkColor: widget.inkColor,
                onTap: () => setState(() => _mode = 'photo'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          if (_mode == 'presets')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _premadeIcons.map((e) {
                final selected = e == widget.current;
                return GestureDetector(
                  onTap: () => widget.onSelected(e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 52,
                    height: 52,
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
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                );
              }).toList(),
            )
          else if (_mode == 'emoji')
            SizedBox(
              height: 320,
              child: epf.EmojiPicker(
                onEmojiSelected: (_, emoji) => widget.onSelected(emoji.emoji),
                config: epf.Config(
                  emojiViewConfig: epf.EmojiViewConfig(
                    backgroundColor: widget.surfaceColor,
                    emojiSizeMax: 28,
                  ),
                  searchViewConfig: epf.SearchViewConfig(
                    backgroundColor: widget.surfaceColor,
                    buttonIconColor: widget.inkColor,
                  ),
                  categoryViewConfig: epf.CategoryViewConfig(
                    backgroundColor: widget.surfaceColor,
                    iconColor: widget.inkColor.withOpacity(0.4),
                    iconColorSelected: widget.inkColor,
                    indicatorColor: widget.inkColor,
                  ),
                  bottomActionBarConfig: const epf.BottomActionBarConfig(
                    enabled: false,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _uploading ? null : _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: widget.surfaceSoftColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.lineColor,
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _uploading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: widget.inkColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: widget.inkMutedColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pick from gallery',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.inkMutedColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
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

// Renders an event icon — either a network image (URL) or emoji text.
class _EventIconDisplay extends StatelessWidget {
  const _EventIconDisplay({required this.icon, this.size = 28});
  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (_isEventIconUrl(icon)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          icon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    return Text(icon, style: TextStyle(fontSize: size));
  }
}

// ── RSVP section ──────────────────────────────────────────────────────────────

class _RsvpSection extends StatelessWidget {
  const _RsvpSection({
    required this.detail,
    required this.loading,
    required this.onVote,
  });

  final EventRsvpDetail detail;
  final bool loading;
  final void Function(String status) onVote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTENDANCE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.appColors.inkMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.appColors.inkMuted,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              _RsvpButton(
                emoji: '✅',
                label: 'Going',
                value: 'attending',
                current: detail.myStatus,
                count: detail.attending.length,
                onTap: () => onVote('attending'),
              ),
              const SizedBox(width: 8),
              _RsvpButton(
                emoji: '❌',
                label: 'Not going',
                value: 'not_attending',
                current: detail.myStatus,
                count: detail.notAttending.length,
                onTap: () => onVote('not_attending'),
              ),
              const SizedBox(width: 8),
              _RsvpButton(
                emoji: '🤔',
                label: 'Unsure',
                value: 'unsure',
                current: detail.myStatus,
                count: detail.unsure.length,
                onTap: () => onVote('unsure'),
              ),
            ],
          ),
          if (detail.attending.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${detail.attending.length} going: ${detail.attending.take(3).map((u) => u.userName).join(', ')}${detail.attending.length > 3 ? ' +${detail.attending.length - 3}' : ''}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: context.appColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.emoji,
    required this.label,
    required this.value,
    required this.current,
    required this.count,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String value;
  final String? current;
  final int count;
  final VoidCallback onTap;

  static const _colors = {
    'attending': (bg: Color(0xFFD4EDDA), border: Color(0xFF28A745)),
    'not_attending': (bg: Color(0xFFF8D7DA), border: Color(0xFFDC3545)),
    'unsure': (bg: Color(0xFFFFF3CD), border: Color(0xFFE5B130)),
  };

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    final palette = _colors[value]!;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? palette.bg : context.appColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? palette.border : context.appColors.line,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 3),
              Text(
                count > 0 ? '$count' : label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? palette.border
                      : context.appColors.inkMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
