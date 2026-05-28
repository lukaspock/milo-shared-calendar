import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _googleLoading = false;

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    await ref.read(authProvider.notifier).googleSignIn();
    if (mounted) setState(() => _googleLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, state) {
      if (!mounted) return;
      if (state.status == AuthStatus.authenticated) {
        // New users go through onboarding; existing users go straight home
        context.go(state.isNewUser ? '/onboarding/calendar' : '/home');
      } else if (state.error != null) {
        setState(() => _googleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // ── Illustration ──────────────────────────────────────────────
              Center(child: _WelcomeIllustration()),

              const SizedBox(height: 40),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                'Welcome to\nShared Calendar.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Built to connect.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.inkSoft,
                ),
              ),

              const Spacer(flex: 3),

              // ── Continue with Google ───────────────────────────────────────
              _SocialButton(
                onPressed: _googleLoading ? null : _googleSignIn,
                isLoading: _googleLoading,
                label: 'Continue with Google',
                icon: _GoogleG(),
                style: _SocialStyle.outlined,
              ),

              const SizedBox(height: 10),

              // ── Continue with Apple ────────────────────────────────────────
              _SocialButton(
                onPressed: () => _showAppleComingSoon(context),
                isLoading: false,
                label: 'Continue with Apple',
                icon: const Icon(Icons.apple, size: 20, color: Colors.white),
                style: _SocialStyle.dark,
              ),

              const SizedBox(height: 24),

              // ── Divider ───────────────────────────────────────────────────
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

              const SizedBox(height: 20),

              // ── Use email instead ─────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/onboarding/name'),
                  child: Text(
                    'Use email instead →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.accent,
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

// ── Social button ─────────────────────────────────────────────────────────────

enum _SocialStyle { outlined, dark }

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.style,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final Widget icon;
  final _SocialStyle style;

  @override
  Widget build(BuildContext context) {
    final isDark = style == _SocialStyle.dark;
    return SizedBox(
      height: 54,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.ink : AppTheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: isDark
                  ? null
                  : Border.all(color: AppTheme.line, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? AppTheme.ink.withValues(alpha: 0.18)
                      : AppTheme.line.withValues(alpha: 0.5),
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: isDark ? Colors.white : AppTheme.inkMuted,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Google "G" logo ───────────────────────────────────────────────────────────

class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        'G',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white, // masked by ShaderMask
        ),
      ),
    );
  }
}

// ── Sticker illustration ──────────────────────────────────────────────────────

class _WelcomeIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: 28,
            child: Transform.rotate(
              angle: -0.22,
              child: StickerTile(
                hue: stickerHues[0],
                size: 100,
                radius: 26,
                child: const Text('📅', style: TextStyle(fontSize: 42)),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 18,
            child: Transform.rotate(
              angle: 0.18,
              child: StickerTile(
                hue: stickerHues[3],
                size: 100,
                radius: 26,
                child: const Text('👥', style: TextStyle(fontSize: 42)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Apple "coming soon" dialog ────────────────────────────────────────────────

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
