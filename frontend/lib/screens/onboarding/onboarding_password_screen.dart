import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_text_field.dart';
import '../onboarding/onboarding_shell.dart';

class OnboardingPasswordScreen extends ConsumerStatefulWidget {
  const OnboardingPasswordScreen({super.key});

  @override
  ConsumerState<OnboardingPasswordScreen> createState() =>
      _OnboardingPasswordScreenState();
}

class _OnboardingPasswordScreenState
    extends ConsumerState<OnboardingPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
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
      if (state.status == AuthStatus.authenticated) {
        context.go('/onboarding/verify');
      } else if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    });

    return OnboardingShell(
      step: 3,
      totalSteps: 5,
      onBack: () => context.go('/onboarding/email'),
      illustration: AppImages.lock(size: 72),
      illustrationHue: stickerHues[4],
      title: 'Create a password',
      subtitle: 'At least 6 characters. You can always change it later.',
      buttonLabel: 'Create account',
      isLoading: isLoading,
      onContinue: isLoading ? null : _continue,
      child: Form(
        key: _formKey,
        child: AppTextField(
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
              color: context.appColors.inkMuted,
              size: 18,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => isLoading ? null : _continue(),
          validator: (v) =>
              v != null && v.length >= 6 ? null : 'Min 6 characters',
        ),
      ),
    );
  }
}
