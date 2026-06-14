import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'onboarding_shell.dart';

/// S4 — Check your inbox (email verification).
class OnboardingVerifyScreen extends ConsumerStatefulWidget {
  const OnboardingVerifyScreen({super.key});

  @override
  ConsumerState<OnboardingVerifyScreen> createState() =>
      _OnboardingVerifyScreenState();
}

class _OnboardingVerifyScreenState extends ConsumerState<OnboardingVerifyScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _resending = false;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => ref.read(authProvider.notifier).refreshUser(),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
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
      totalSteps: 7,
      onBack: null,
      customHeader: ScaleTransition(
        scale: _pulse,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D0),
            borderRadius: BorderRadius.circular(28),
          ),
          alignment: Alignment.center,
          child: const Text('📬', style: TextStyle(fontSize: 48)),
        ),
      ),
      title: 'Check your inbox',
      subtitle: 'We sent a verification link to:',
      buttonLabel: 'Skip for now',
      onContinue: () => context.go('/onboarding/calendar'),
      isSecondaryButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email address bold
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.appColors.ink,
            ),
          ),
          const SizedBox(height: 20),

          // Waiting pill
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D0),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0xFFE5B130), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD88818),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for verification…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD88818),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Resend / confirmation
          Center(
            child: GestureDetector(
              onTap: _resending || _resent
                  ? null
                  : () async {
                      setState(() => _resending = true);
                      final ok = await ref
                          .read(authProvider.notifier)
                          .resendVerification();
                      if (!mounted) return;
                      setState(() {
                        _resending = false;
                        _resent = ok;
                      });
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not send email. Try again.'),
                          ),
                        );
                      }
                    },
              child: _resent
                  ? Text(
                      '✓ Email resent!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4FA870),
                      ),
                    )
                  : Text(
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
