import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'onboarding_shell.dart';

/// Step 1 — auth method choice. No personal info collected here.
/// Google/Apple sign directly; email path collects name+email on the next screen.
class OnboardingNameEmailScreen extends ConsumerStatefulWidget {
  const OnboardingNameEmailScreen({super.key});

  @override
  ConsumerState<OnboardingNameEmailScreen> createState() =>
      _OnboardingNameEmailScreenState();
}

class _OnboardingNameEmailScreenState
    extends ConsumerState<OnboardingNameEmailScreen> {

  Future<void> _googleSignIn() async {
    await ref.read(authProvider.notifier).googleSignIn();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated && mounted) {
        context.go('/onboarding/calendar');
      } else if (state.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    });

    return OnboardingShell(
      step: 1,
      totalSteps: 4,
      onBack: () => context.go('/welcome'),
      illustration: const Text('👋', style: TextStyle(fontSize: 72)),
      illustrationHue: stickerHues[1],
      title: "Let's get started",
      subtitle: 'Choose how you\'d like to continue.',
      buttonLabel: '',
      onContinue: null,
      hideButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Continue with Google ────────────────────────────────────────
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: isLoading ? null : _googleSignIn,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                backgroundColor: AppTheme.surface,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.inkMuted),
                    )
                  else ...[
                    Text(
                      'G',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
                          ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Continue with Apple ─────────────────────────────────────────
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed:
                  isLoading ? null : () => _showAppleComingSoon(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apple, size: 22, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Apple',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Divider ─────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: Divider(color: AppTheme.line, thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.inkMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.line, thickness: 1.5)),
          ]),

          const SizedBox(height: 16),

          // ── Use Email ───────────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: isLoading ? null : () => context.go('/onboarding/email'),
              child: Text(
                'Use email instead →',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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

void _showAppleComingSoon(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.apple, size: 22, color: AppTheme.ink),
          const SizedBox(width: 10),
          Text(
            'Apple Sign-In',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
      content: Text(
        'Apple Sign-In is not yet implemented.\nUse email or Google for now.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppTheme.inkSoft,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Got it',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
        ),
      ],
    ),
  );
}
