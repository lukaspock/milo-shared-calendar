import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/app_text_field.dart';
import 'onboarding_shell.dart';

/// S2 — Create your account (name + email).
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
    _nameCtrl  = TextEditingController(text: saved.name);
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
    // Dot-progress: S2 is dot 1 of 7.
    return OnboardingShell(
      step: 1,
      totalSteps: 7,
      onBack: () => context.go('/welcome'),
      customHeader: const OnboardingIconBlock(
        bg: Color(0xFFDDEEFF),
        child: Text('✉️', style: TextStyle(fontSize: 30)),
      ),
      title: 'Create your account',
      subtitle: 'Enter your name and email to get started.',
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
              prefixIcon: Icons.person_outline_rounded,
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
              prefixIcon: Icons.mail_outline_rounded,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
              validator: (v) =>
                  v != null && v.contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            Text(
              'By continuing you agree to our Terms of Service and Privacy Policy.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF7A6A52)
                    : const Color(0xFF8A7060),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
