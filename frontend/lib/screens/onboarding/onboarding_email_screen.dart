import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/onboarding_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import 'onboarding_shell.dart';

class OnboardingEmailScreen extends ConsumerStatefulWidget {
  const OnboardingEmailScreen({super.key});

  @override
  ConsumerState<OnboardingEmailScreen> createState() =>
      _OnboardingEmailScreenState();
}

class _OnboardingEmailScreenState
    extends ConsumerState<OnboardingEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl =
        TextEditingController(text: ref.read(onboardingProvider).email);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final name = ref.read(onboardingProvider).name;
    ref
        .read(onboardingProvider.notifier)
        .setNameEmail(name, _emailCtrl.text.trim());
    context.go('/onboarding/password');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 2,
      totalSteps: 4,
      onBack: () => context.go('/onboarding/name'),
      illustration:
          const Text('✉️', style: TextStyle(fontSize: 72)),
      illustrationHue: stickerHues[2],
      title: "What's your email?",
      subtitle: "We'll send you a confirmation link to verify your account.",
      buttonLabel: 'Continue',
      onContinue: _continue,
      child: Form(
        key: _formKey,
        child: AppTextField(
          controller: _emailCtrl,
          label: 'Email',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continue(),
          validator: (v) =>
              v != null && v.contains('@') ? null : 'Enter a valid email',
        ),
      ),
    );
  }
}
