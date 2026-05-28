import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated) {
        context.go('/home');
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // ── Hero sticker tiles ──────────────────────────────────
                  _HeroTiles(),

                  const SizedBox(height: 36),

                  // ── Heading ─────────────────────────────────────────────
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

                  const SizedBox(height: 36),

                  // ── Email ────────────────────────────────────────────────
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) =>
                        v != null && v.contains('@') ? null : 'Enter a valid email',
                  ),
                  const SizedBox(height: 14),

                  // ── Password ─────────────────────────────────────────────
                  AppTextField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    hint: '••••••••',
                    obscureText: _obscure,
                    prefixIcon: Icons.lock_outline_rounded,
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

                  const SizedBox(height: 28),

                  // ── Sign in button ────────────────────────────────────────
                  AppButton(
                    label: 'Sign in →',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                  ),

                  const SizedBox(height: 16),

                  // ── Divider ───────────────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: AppTheme.line, thickness: 1.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.inkMuted, fontSize: 13, fontWeight: FontWeight.w500,
                      )),
                    ),
                    Expanded(child: Divider(color: AppTheme.line, thickness: 1.5)),
                  ]),

                  const SizedBox(height: 16),

                  // ── Google Sign-In ────────────────────────────────────────
                  _GoogleSignInButton(isLoading: isLoading),

                  const SizedBox(height: 28),

                  // ── Footer link ───────────────────────────────────────────
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
                              text: 'Create an account',
                              style: GoogleFonts.plusJakartaSans(
                                color: stickerHues[0].deep,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: stickerHues[0].deep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends ConsumerWidget {
  final bool isLoading;
  const _GoogleSignInButton({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () => ref.read(authProvider.notifier).googleSignIn(),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppTheme.line, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: AppTheme.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo using coloured text
            Text('G', style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w800,
              foreground: Paint()..shader = const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
              ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
            )),
            const SizedBox(width: 10),
            Text('Continue with Google', style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.ink,
            )),
          ],
        ),
      ),
    );
  }
}

class _HeroTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Peach tile (left, rotated -9°)
          Positioned(
            left: 0,
            top: 8,
            child: Transform.rotate(
              angle: -0.157,
              child: StickerTile(
                hue: stickerHues[0],
                size: 72,
                radius: 18,
                child: const Text('📅', style: TextStyle(fontSize: 30)),
              ),
            ),
          ),
          // Mint tile (centre, rotated +4°)
          Positioned(
            left: 52,
            top: 4,
            child: Transform.rotate(
              angle: 0.07,
              child: StickerTile(
                hue: stickerHues[1],
                size: 72,
                radius: 18,
                child: const Text('👥', style: TextStyle(fontSize: 30)),
              ),
            ),
          ),
          // Lilac tile (right, rotated +11°)
          Positioned(
            left: 104,
            top: 0,
            child: Transform.rotate(
              angle: 0.192,
              child: StickerTile(
                hue: stickerHues[3],
                size: 72,
                radius: 18,
                child: const Text('⭐', style: TextStyle(fontSize: 30)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
