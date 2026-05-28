import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../onboarding/onboarding_shell.dart';

class OnboardingCalendarScreen extends ConsumerStatefulWidget {
  const OnboardingCalendarScreen({super.key});

  @override
  ConsumerState<OnboardingCalendarScreen> createState() =>
      _OnboardingCalendarScreenState();
}

class _OnboardingCalendarScreenState
    extends ConsumerState<OnboardingCalendarScreen>
    with WidgetsBindingObserver {
  bool _connecting = false;

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
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.user?.hasGoogleCalendar == true && mounted) {
        context.go('/onboarding/ready');
      }
    });

    final alreadyConnected = user?.hasGoogleCalendar == true;

    return OnboardingShell(
      step: 4,
      totalSteps: 4,
      onBack: null,
      illustration: const Text('🗓️', style: TextStyle(fontSize: 72)),
      illustrationHue: stickerHues[2],
      title: 'Connect Google Calendar',
      subtitle:
          'Events you create in SharedCal will automatically sync to your Google Calendar.',
      buttonLabel: 'Skip for now',
      onContinue: () => context.go('/onboarding/ready'),
      isSecondaryButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alreadyConnected)
            _ConnectedChip()
          else
            AppButton(
              label: _connecting ? 'Opening…' : 'Connect Google Calendar',
              isLoading: _connecting,
              onPressed: _connecting
                  ? null
                  : () async {
                      setState(() => _connecting = true);
                      final url = await ref
                          .read(authProvider.notifier)
                          .getGoogleCalendarConnectUrl();
                      if (!mounted) return;
                      setState(() => _connecting = false);
                      if (url == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Could not get connect URL. Is backend running?')),
                        );
                        return;
                      }
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    },
            ),

          const SizedBox(height: 12),

          // More services hint
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line, width: 1),
            ),
            child: Row(
              children: [
                const Text('🔌', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'More calendar integrations coming soon.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFC9EBD9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F9D60), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Text(
            'Google Calendar connected!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F5C42),
            ),
          ),
        ],
      ),
    );
  }
}
