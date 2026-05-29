import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../providers/onboarding_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialise from whatever is already stored (default: push).
    _notifType = ref.read(onboardingProvider).notificationType;
  }

  Future<void> _onChanged(NotificationType type) async {
    setState(() => _notifType = type);
    ref.read(onboardingProvider.notifier).setNotificationType(type);
    if (type == NotificationType.push) {
      await LocalNotificationService().requestPermission();
    }
  }

  void _continue() {
    // Choice already saved in the provider; just navigate forward.
    context.go('/onboarding/password');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 3,
      totalSteps: 5,
      onBack: () => context.go('/onboarding/email'),
      illustration: AppImages.bell(size: 72),
      illustrationHue: stickerHues[1],
      title: 'Stay in the loop',
      subtitle:
          'Choose how you want to hear about new events. You can change this anytime in Settings.',
      buttonLabel: 'Continue',
      onContinue: _continue,
      child: NotificationTypeSelector(
        value: _notifType,
        onChanged: _onChanged,
      ),
    );
  }
}
