import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated) {
        context.go('/home');
      }
    });

    final isLoading =
        ref.watch(authProvider).status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // ── Illustration ─────────────────────────────────────────────
              Center(child: _WelcomeIllustration()),

              const SizedBox(height: 44),

              // ── Title + tagline ──────────────────────────────────────────
              Text(
                'SharedCal',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  letterSpacing: -2.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Built to connect.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSoft,
                ),
              ),

              const Spacer(flex: 3),

              // ── Get Started ──────────────────────────────────────────────
              _AccentButton(
                label: 'Get Started',
                onPressed:
                    isLoading ? null : () => context.go('/onboarding/name-email'),
              ),

              const SizedBox(height: 12),

              // ── Continue with Google ─────────────────────────────────────
              _GoogleWelcomeButton(isLoading: isLoading),

              const SizedBox(height: 28),

              // ── Sign in link ─────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap:
                      isLoading ? null : () => context.go('/login'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.inkSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign in',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.ink,
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

class _WelcomeIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back tile (rotated left)
          Positioned(
            left: 10,
            top: 30,
            child: Transform.rotate(
              angle: -0.22,
              child: StickerTile(
                hue: stickerHues[0],
                size: 110,
                radius: 28,
                child: const Text('📅', style: TextStyle(fontSize: 48)),
              ),
            ),
          ),
          // Front tile (rotated right, slightly overlapping)
          Positioned(
            right: 10,
            top: 20,
            child: Transform.rotate(
              angle: 0.18,
              child: StickerTile(
                hue: stickerHues[3],
                size: 110,
                radius: 28,
                child: const Text('👥', style: TextStyle(fontSize: 48)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Purple accent button used only on the welcome screen
class _AccentButton extends StatelessWidget {
  const _AccentButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
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

class _GoogleWelcomeButton extends ConsumerWidget {
  const _GoogleWelcomeButton({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed:
            isLoading ? null : () => ref.read(authProvider.notifier).googleSignIn(),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppTheme.line, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: AppTheme.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  color: AppTheme.ink),
            ),
          ],
        ),
      ),
    );
  }
}
