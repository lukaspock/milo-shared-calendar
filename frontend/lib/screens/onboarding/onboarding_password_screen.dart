import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/app_text_field.dart';
import 'onboarding_shell.dart';

/// S3 — Create a password (with live strength meter).
class OnboardingPasswordScreen extends ConsumerStatefulWidget {
  const OnboardingPasswordScreen({super.key});

  @override
  ConsumerState<OnboardingPasswordScreen> createState() =>
      _OnboardingPasswordScreenState();
}

class _OnboardingPasswordScreenState
    extends ConsumerState<OnboardingPasswordScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  int get _strength {
    final len = _passwordCtrl.text.length;
    if (len == 0) return 0;
    if (len < 8) return 1;
    if (len < 12) return 2;
    return 3;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final data = ref.read(onboardingProvider);
    await ref.read(authProvider.notifier).register(
          data.email,
          _passwordCtrl.text,
          data.name,
          notificationType: data.notificationType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated && mounted) {
        context.go('/onboarding/verify');
      } else if (state.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    });

    return OnboardingShell(
      step: 2,
      totalSteps: 7,
      onBack: () => context.go('/onboarding/email'),
      customHeader: const OnboardingIconBlock(
        bg: Color(0xFFFFF3D0),
        child: Text('🔐', style: TextStyle(fontSize: 30)),
      ),
      title: 'Create a password',
      subtitle: 'At least 8 characters. You can always change it later.',
      buttonLabel: 'Create account',
      isLoading: isLoading,
      onContinue: isLoading ? null : _continue,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => isLoading ? null : _continue(),
              validator: (v) =>
                  v != null && v.length >= 8 ? null : 'Min 8 characters',
            ),
            const SizedBox(height: 10),
            _StrengthMeter(strength: _strength),
          ],
        ),
      ),
    );
  }
}

// ── Strength meter ────────────────────────────────────────────────────────────

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});
  final int strength; // 0=empty, 1=weak, 2=good, 3=strong

  static const _labels  = ['', 'Too short', 'Good', 'Strong'];
  static const _colors  = [
    Colors.transparent,
    Color(0xFFEF5350),
    Color(0xFFF5A623),
    Color(0xFF4FA870),
  ];

  @override
  Widget build(BuildContext context) {
    if (strength == 0) return const SizedBox.shrink();

    final color = _colors[strength];
    final label = _labels[strength];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < strength;
            return Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : const Color(0x17000000),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
