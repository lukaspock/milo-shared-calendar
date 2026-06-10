import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _emailSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(authProvider).status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated) {
        context.go('/home');
      }
      // errors are handled inside the bottom sheet
    });

    return Scaffold(
      backgroundColor: context.appColors.bg,
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
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.appColors.line, width: 1.5),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 18, color: context.appColors.ink),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Logo tiles ───────────────────────────────────────────────
              Center(child: _HeroTiles()),

              const SizedBox(height: 32),

              // ── Heading ──────────────────────────────────────────────────
              Text(
                'Welcome back.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your shared calendars.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: context.appColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 3),

              // All 3 buttons constrained to 420 px to match GIS renderButton's
              // max width; height 44 px to match GIS renderButton's height.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Continue with Google ───────────────────────────────
                      // When the email sheet is open the GIS platform view is
                      // replaced with a plain Flutter widget so its native
                      // overlay doesn't sit above the sheet and intercept taps.
                      if (_emailSheetOpen)
                        _GooglePlaceholderButton(isLoading: isLoading)
                      else
                        GoogleSignInButton(
                          isLoading: isLoading,
                          onSignedIn: (idToken) =>
                              ref.read(authProvider.notifier).googleSignIn(idToken),
                          onError: (e) => ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e))),
                        ),

                      const SizedBox(height: 10),

                      // ── Continue with Apple ────────────────────────────────
                      _SocialButton(
                        label: 'Continue with Apple',
                        isLoading: isLoading,
                        onPressed: () => _showAppleComingSoon(context),
                        leading: const Icon(Icons.apple,
                            size: 20, color: Colors.white),
                        dark: true,
                      ),

                      const SizedBox(height: 10),

                      // ── Use Email ──────────────────────────────────────────
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => _showEmailSignIn(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.appColors.line, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22)),
                            backgroundColor: context.appColors.surface,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mail_outline_rounded,
                                  size: 17, color: context.appColors.inkSoft),
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

              const SizedBox(height: 32),

              // ── Footer ───────────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/welcome'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        color: context.appColors.inkSoft,
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

  void _showEmailSignIn(BuildContext context) {
    setState(() => _emailSheetOpen = true);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _EmailSignInSheet(),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _emailSheetOpen = false);
    });
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
      decoration: BoxDecoration(
        color: context.appColors.surface,
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
                  color: context.appColors.line,
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
                color: context.appColors.ink,
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
                  color: context.appColors.inkMuted,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : 'Min 6 characters',
            ),

            const SizedBox(height: 8),

            // ── Forgot password ───────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ProviderScope(
                      parent: ProviderScope.containerOf(context),
                      child: _ForgotPasswordSheet(
                        prefillEmail: _emailCtrl.text.trim(),
                      ),
                    ),
                  );
                },
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.inkSoft,
                    decoration: TextDecoration.underline,
                    decorationColor: context.appColors.inkMuted,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

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

// ── Forgot-password bottom sheet ──────────────────────────────────────────────

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet({this.prefillEmail = ''});
  final String prefillEmail;

  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.prefillEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).forgotPassword(email);
      if (mounted) setState(() { _sent = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Something went wrong. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: context.appColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _sent ? 'Check your email' : 'Forgot password?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: context.appColors.ink, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sent
                ? 'If an account exists for that address, we\'ve sent a reset link. It expires in 1 hour.'
                : 'Enter your email and we\'ll send you a link to reset your password.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: context.appColors.inkSoft, height: 1.5,
            ),
          ),
          if (!_sent) ...[
            const SizedBox(height: 20),
            AppTextField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: AppTheme.danger)),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Send reset link →',
              onPressed: _loading ? null : _submit,
              isLoading: _loading,
            ),
          ] else ...[
            const SizedBox(height: 24),
            AppButton(
              label: 'Back to sign in',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: dark
          ? ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.black : context.appColors.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: _buttonContent(context),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.appColors.line, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                backgroundColor: context.appColors.surface,
              ),
              child: _buttonContent(context),
            ),
    );
  }

  Widget _buttonContent(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : context.appColors.ink,
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

// Plain Flutter button shown in place of GoogleSignInButton while the email
// sheet is open, so the GIS platform view overlay doesn't block the sheet.
class _GooglePlaceholderButton extends StatelessWidget {
  const _GooglePlaceholderButton({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.appColors.line, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          backgroundColor: context.appColors.surface,
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
                color: context.appColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/app_icon.png',
      width: 100,
      height: 100,
    );
  }
}
