import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_shell.dart';

class OnboardingVerifyScreen extends ConsumerStatefulWidget {
  const OnboardingVerifyScreen({super.key});

  @override
  ConsumerState<OnboardingVerifyScreen> createState() =>
      _OnboardingVerifyScreenState();
}

class _OnboardingVerifyScreenState
    extends ConsumerState<OnboardingVerifyScreen> {
  Timer? _timer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(authProvider.notifier).refreshUser();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.user?.emailVerified == true && mounted) {
        context.go('/onboarding/calendar');
      }
    });

    final email = user?.email ?? 'your email';

    return OnboardingShell(
      step: 3,
      totalSteps: 4,
      onBack: null,
      illustration: const Text('📬', style: TextStyle(fontSize: 72)),
      illustrationHue: stickerHues[4],
      title: 'Check your inbox',
      subtitle: 'We sent a link to $email.\nClick it to verify your account.',
      buttonLabel: 'Skip for now',
      onContinue: () => context.go('/onboarding/calendar'),
      isSecondaryButton: true,
      child: Column(
        children: [
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFE5B130), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE5B130),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Waiting for verification…',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7A5A14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Resend button
          Center(
            child: GestureDetector(
              onTap: _resending
                  ? null
                  : () async {
                      setState(() => _resending = true);
                      final ok =
                          await ref.read(authProvider.notifier).resendVerification();
                      if (!mounted) return;
                      setState(() => _resending = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Verification email sent!'
                            : 'Could not send email. Try again.'),
                      ));
                    },
              child: Text(
                _resending ? 'Sending…' : 'Resend email',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
