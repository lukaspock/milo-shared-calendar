import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class OnboardingReadyScreen extends ConsumerWidget {
  const OnboardingReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

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
              Center(
                child: _ReadyIllustration(),
              ),

              const SizedBox(height: 48),

              // ── Title ────────────────────────────────────────────────────
              Text(
                user != null
                    ? 'You\'re all set,\n${user.name.split(' ').first}!'
                    : 'You\'re all set!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Shared Calendar is ready to help you plan with the people that matter.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppTheme.inkSoft,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // ── CTA ──────────────────────────────────────────────────────
              SizedBox(
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        offset: const Offset(0, 6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
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
                      'Start planning →',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: -0.15,
          child: StickerTile(
            hue: stickerHues[4],
            size: 120,
            radius: 30,
            child: const Text('🎉', style: TextStyle(fontSize: 52)),
          ),
        ),
        Positioned(
          right: -20,
          bottom: -10,
          child: Transform.rotate(
            angle: 0.2,
            child: StickerTile(
              hue: stickerHues[1],
              size: 70,
              radius: 18,
              child: const Text('✨', style: TextStyle(fontSize: 28)),
            ),
          ),
        ),
        Positioned(
          left: -14,
          top: -8,
          child: Transform.rotate(
            angle: -0.1,
            child: StickerTile(
              hue: stickerHues[3],
              size: 60,
              radius: 16,
              child: const Text('📅', style: TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ],
    );
  }
}
