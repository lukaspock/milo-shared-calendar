import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_notification_service.dart';
import '../onboarding/onboarding_shell.dart';

const _kAccent = Color(0xFFF5A623);

/// S6 — Stay in the loop (notification preference, multi-select).
class OnboardingNotificationsScreen extends ConsumerStatefulWidget {
  const OnboardingNotificationsScreen({super.key});

  @override
  ConsumerState<OnboardingNotificationsScreen> createState() =>
      _OnboardingNotificationsScreenState();
}

class _OnboardingNotificationsScreenState
    extends ConsumerState<OnboardingNotificationsScreen> {
  bool _push = true;
  bool _email = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _push = user.notificationType == NotificationType.push;
      _email = user.notificationType == NotificationType.email;
    }
  }

  NotificationType get _resolvedType =>
      _email ? NotificationType.email : NotificationType.push;

  Future<void> _continue() async {
    setState(() => _saving = true);
    if (_push) await LocalNotificationService().requestPermission();
    await ref.read(authProvider.notifier).updateNotificationType(_resolvedType);
    if (mounted) context.go('/onboarding/avatar');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 5,
      totalSteps: 7,
      onBack: () => context.go('/onboarding/calendar'),
      customHeader: const OnboardingIconBlock(
        bg: Color(0xFFE8F8EE),
        child: Text('🔔', style: TextStyle(fontSize: 30)),
      ),
      title: 'Stay in the loop',
      subtitle: 'Choose how you want to hear about new events.',
      buttonLabel: 'Continue',
      isLoading: _saving,
      onContinue: _saving ? null : _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NotifRow(
            emoji: '🔔',
            title: 'On my phone',
            sub: 'Pop-up alerts on this device',
            selected: _push,
            onTap: () => setState(() => _push = !_push),
          ),
          const SizedBox(height: 10),
          _NotifRow(
            emoji: '✉️',
            title: 'Email',
            sub: 'Get an email each time',
            selected: _email,
            onTap: () => setState(() => _email = !_email),
          ),
        ],
      ),
    );
  }
}

// ── Notification selection row ────────────────────────────────────────────────

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x28F5A623) // ACCENT 18% opacity
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _kAccent : const Color(0x17000000),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon block
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x40F5A623) // ACCENT 25%
                    : const Color(0xFFF0E4D4),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF0E8D8)
                          : const Color(0xFF1A1008),
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8A7060),
                    ),
                  ),
                ],
              ),
            ),
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? _kAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _kAccent : const Color(0x17000000),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
