import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading =
        ref.watch(authProvider).status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated) {
        context.go('/home');
      }
      // errors are handled inside the bottom sheet
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ── Back button ──────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.go('/welcome'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.line, width: 1.5),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: AppTheme.ink),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Logo tiles ───────────────────────────────────────────────
              _HeroTiles(),

              const SizedBox(height: 32),

              // ── Heading ──────────────────────────────────────────────────
              Text(
                'Welcome back.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your shared calendars.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: AppTheme.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              // ── Continue with Google ─────────────────────────────────────
              _SocialButton(
                label: 'Continue with Google',
                isLoading: isLoading,
                onPressed: () =>
                    ref.read(authProvider.notifier).googleSignIn(),
                leading: Text(
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
                dark: false,
              ),

              const SizedBox(height: 10),

              // ── Continue with Apple ──────────────────────────────────────
              _SocialButton(
                label: 'Continue with Apple',
                isLoading: isLoading,
                onPressed: () => _showAppleComingSoon(context),
                leading: const Icon(Icons.apple,
                    size: 22, color: Colors.white),
                dark: true,
              ),

              const SizedBox(height: 20),

              // ── Use Email ────────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: isLoading
                      ? null
                      : () => _showEmailSignIn(context, ref),
                  child: Text(
                    'Use email instead',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.inkSoft,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.inkMuted,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Footer ───────────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/welcome'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.inkSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'New here? '),
                        TextSpan(
                          text: 'Get Started',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailSignIn(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _EmailSignInSheet(),
      ),
    );
  }
}

// ── Email sign-in bottom sheet ────────────────────────────────────────────────

class _EmailSignInSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EmailSignInSheet> createState() => _EmailSignInSheetState();
}

class _EmailSignInSheetState extends ConsumerState<_EmailSignInSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(authProvider).status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated && mounted) {
        Navigator.of(context).pop(); // close sheet
        // LoginScreen's listener handles going to /home
      } else if (state.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    });

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Grabber ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ────────────────────────────────────────────────────
            Text(
              'Sign in with email',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 20),

            // ── Email ────────────────────────────────────────────────────
            AppTextField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v != null && v.contains('@') ? null : 'Enter a valid email',
            ),

            const SizedBox(height: 14),

            // ── Password ─────────────────────────────────────────────────
            AppTextField(
              controller: _passwordCtrl,
              label: 'Password',
              hint: '••••••••',
              obscureText: _obscure,
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => isLoading ? null : _submit(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.inkMuted,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : 'Min 6 characters',
            ),

            const SizedBox(height: 24),

            // ── Sign in button ────────────────────────────────────────────
            AppButton(
              label: 'Sign in →',
              onPressed: isLoading ? null : _submit,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared social button ──────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.onPressed,
    required this.leading,
    required this.dark,
    required this.isLoading,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget leading;
  final bool dark;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: dark
          ? ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: _buttonContent(),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.line, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                backgroundColor: AppTheme.surface,
              ),
              child: _buttonContent(),
            ),
    );
  }

  Widget _buttonContent() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : AppTheme.ink,
            ),
          ),
        ],
      );
}

// ── Apple coming soon ─────────────────────────────────────────────────────────

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

// ── Hero sticker tiles ────────────────────────────────────────────────────────

class _HeroTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 8,
            child: Transform.rotate(
              angle: -0.157,
              child: StickerTile(
                hue: stickerHues[0],
                size: 68,
                radius: 18,
                child: const Text('📅', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
          Positioned(
            left: 52,
            top: 4,
            child: Transform.rotate(
              angle: 0.07,
              child: StickerTile(
                hue: stickerHues[1],
                size: 68,
                radius: 18,
                child: const Text('👥', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
          Positioned(
            left: 104,
            top: 0,
            child: Transform.rotate(
              angle: 0.192,
              child: StickerTile(
                hue: stickerHues[3],
                size: 68,
                radius: 18,
                child: const Text('⭐', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
