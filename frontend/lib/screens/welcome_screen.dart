import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

// Pastel orange — warmer than the default bg, used only on this screen (light mode).
const _kWelcomeBg = Color(0xFFFFEDD8);
const _kButtonOrange = Color(0xFFFFB347);

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? context.appColors.bg : _kWelcomeBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // ── Milo logo ─────────────────────────────────────────────────
              Center(
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 200,
                  height: 200,
                ),
              ),

              const SizedBox(height: 36),

              // ── Title ────────────────────────────────────────────────────
              Text(
                'Welcome to\nMilo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.ink,
                  letterSpacing: -2,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Stay in sync.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.inkSoft,
                ),
              ),

              const Spacer(flex: 3),

              // ── Get Started ──────────────────────────────────────────────
              _AccentButton(
                label: 'Get Started',
                onPressed: () => context.go('/onboarding/name'),
              ),

              const SizedBox(height: 28),

              // ── Sign in link ─────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        color: context.appColors.inkSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign in',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.appColors.ink,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: context.appColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  const _AccentButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // In dark mode use the ink color (cream) as the button background so it
    // stands out clearly against the near-black scaffold; keep orange for light.
    final buttonBg = isDark ? context.appColors.ink : _kButtonOrange;
    // Text on cream ink → use dark bg colour; text on orange → use dark ink.
    final buttonFg = isDark ? context.appColors.bg : context.appColors.ink;

    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: buttonBg.withValues(alpha: 0.35),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonBg,
            foregroundColor: buttonFg,
            minimumSize: const Size(double.infinity, 58),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
