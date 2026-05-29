import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/onboarding_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_text_field.dart';
import 'onboarding_shell.dart';

/// Step 2 of the email path — collect full name + email address.
class OnboardingEmailScreen extends ConsumerStatefulWidget {
  const OnboardingEmailScreen({super.key});

  @override
  ConsumerState<OnboardingEmailScreen> createState() =>
      _OnboardingEmailScreenState();
}

class _OnboardingEmailScreenState
    extends ConsumerState<OnboardingEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingProvider);
    _nameCtrl = TextEditingController(text: saved.name);
    _emailCtrl = TextEditingController(text: saved.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(onboardingProvider.notifier).setNameEmail(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
        );
    context.go('/onboarding/password');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      step: 2,
      totalSteps: 5,
      onBack: () => context.go('/onboarding/name'),
      illustration: AppImages.envelope(size: 72),
      illustrationHue: stickerHues[2],
      title: 'Create your account',
      subtitle: "Enter your name and email to get started.",
      buttonLabel: 'Continue',
      onContinue: _continue,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameCtrl,
              label: 'Full name',
              hint: 'Jane Doe',
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) => v != null && v.trim().isNotEmpty
                  ? null
                  : 'Name is required',
            ),
            const SizedBox(height: 12),
            AppTextField(
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
          ],
        ),
      ),
    );
  }
}
