import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).register(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
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

                  // ── Hero tiles ────────────────────────────────────────────
                  SizedBox(
                    height: 100,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: 8,
                          child: Transform.rotate(
                            angle: -0.14,
                            child: StickerTile(
                              hue: stickerHues[4],
                              size: 72,
                              radius: 18,
                              child: const Text('✨', style: TextStyle(fontSize: 30)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 52,
                          top: 4,
                          child: Transform.rotate(
                            angle: 0.08,
                            child: StickerTile(
                              hue: stickerHues[2],
                              size: 72,
                              radius: 18,
                              child: const Text('🎉', style: TextStyle(fontSize: 30)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 104,
                          top: 0,
                          child: Transform.rotate(
                            angle: 0.19,
                            child: StickerTile(
                              hue: stickerHues[5],
                              size: 72,
                              radius: 18,
                              child: const Text('🌱', style: TextStyle(fontSize: 30)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  Text(
                    'Create account.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join Shared Calendar and start collaborating.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: AppTheme.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 36),

                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Full name',
                    hint: 'Jane Doe',
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) =>
                        v != null && v.trim().isNotEmpty ? null : 'Name is required',
                  ),
                  const SizedBox(height: 14),
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

                  AppButton(
                    label: 'Create account →',
                    onPressed: isLoading ? null : _submit,
                    isLoading: isLoading,
                  ),

                  const SizedBox(height: 16),

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

                  SizedBox(
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
                  ),

                  const SizedBox(height: 28),

                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
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
