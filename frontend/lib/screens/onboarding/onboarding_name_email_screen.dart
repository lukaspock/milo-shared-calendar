import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/google_sign_in_button.dart';
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
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated && mounted) {
        context.go('/onboarding/calendar');
      } else if (state.error != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.error!)));
      }
    });

    return OnboardingShell(
      step: 1,
      totalSteps: 5,
      onBack: () => context.go('/welcome'),
      customHeader: const OnboardingIconBlock(
        bg: Color(0xFFDDEEFF),
        child: Text('👋', style: TextStyle(fontSize: 30)),
      ),
      title: "Let's get started",
      subtitle: 'Choose how you\'d like to continue.',
      buttonLabel: '',
      onContinue: null,
      hideButton: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Continue with Google ──────────────────────────────────────
              GoogleSignInButton(
                isLoading: isLoading,
                onSignedIn: (idToken) =>
                    ref.read(authProvider.notifier).googleSignIn(idToken),
                onError: (e) => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e))),
              ),

              const SizedBox(height: 10),

              // ── Continue with Apple ───────────────────────────────────────
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => _showAppleComingSoon(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : context.appColors.ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apple, size: 20, color: Colors.white),
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

              const SizedBox(height: 10),

              // ── Continue with email ───────────────────────────────────────
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => context.go('/onboarding/email'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.appColors.line, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    backgroundColor: context.appColors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 17,
                        color: context.appColors.inkSoft,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Continue with email',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showAppleComingSoon(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.apple, size: 22, color: context.appColors.ink),
          const SizedBox(width: 10),
          Text(
            'Apple Sign-In',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.appColors.ink,
            ),
          ),
        ],
      ),
      content: Text(
        'Apple Sign-In is not yet implemented.\nUse email or Google for now.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: context.appColors.inkSoft,
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
