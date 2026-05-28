import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated) {
        context.go('/home');
      } else if (state.status == AuthStatus.unauthenticated) {
        context.go('/welcome');
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Three overlapping sticker tiles as logo
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.16,
                    child: StickerTile(
                      hue: stickerHues[0],
                      size: 64,
                      radius: 16,
                      child: const Text('📅', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(10, 0),
                    child: Transform.rotate(
                      angle: 0.18,
                      child: StickerTile(
                        hue: stickerHues[1],
                        size: 64,
                        radius: 16,
                        child: const Text('👥', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Shared Calendar',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Shared calendars, real-time.',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.inkSoft,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
