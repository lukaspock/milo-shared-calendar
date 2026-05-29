import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/notification_type_selector.dart';
import '../onboarding/onboarding_shell.dart';

class OnboardingNotificationsScreen extends ConsumerStatefulWidget {
  const OnboardingNotificationsScreen({super.key});

  @override
  ConsumerState<OnboardingNotificationsScreen> createState() =>
      _OnboardingNotificationsScreenState();
}

class _OnboardingNotificationsScreenState
    extends ConsumerState<OnboardingNotificationsScreen> {
  late NotificationType _notifType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-select whatever the account was registered with (default: push).
    _notifType =
        ref.read(authProvider).user?.notificationType ?? NotificationType.push;
  }

  Future<void> _onChanged(NotificationType type) async {
    setState(() => _notifType = type);
    if (type == NotificationType.push) {
      await LocalNotificationService().requestPermission();
    }
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    // Account already exists — persist the choice via the API.
    await ref.read(authProvider.notifier).updateNotificationType(_notifType);
    if (mounted) context.go('/onboarding/ready');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 5,
      totalSteps: 5,
      onBack: () => context.go('/onboarding/calendar'),
      illustration: AppImages.bell(size: 72),
      illustrationHue: stickerHues[1],
      title: 'Stay in the loop',
      subtitle:
          'Choose how you want to hear about new events. You can change this anytime in Settings.',
      buttonLabel: 'Continue',
      isLoading: _saving,
      onContinue: _saving ? null : _continue,
      child: NotificationTypeSelector(
        value: _notifType,
        onChanged: _onChanged,
      ),
    );
  }
}
