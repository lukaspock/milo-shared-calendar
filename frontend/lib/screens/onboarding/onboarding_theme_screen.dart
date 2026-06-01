import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import 'onboarding_shell.dart';

class OnboardingThemeScreen extends ConsumerWidget {
  const OnboardingThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    return OnboardingShell(
      step: 5,
      totalSteps: 6,
      onBack: null,
      illustration: AppImages.moon(size: 72),
      illustrationHue: stickerHues[3],
      title: 'Choose your look',
      subtitle: 'Pick a theme. You can change it any time in Settings.',
      buttonLabel: 'Continue',
      onContinue: () => context.go('/onboarding/ready'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ThemeOption(
            label: 'System default',
            subtitle: 'Follows your device setting',
            icon: Icons.brightness_auto_rounded,
            selected: current == ThemeMode.system,
            onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.system),
          ),
          const SizedBox(height: 10),
          _ThemeOption(
            label: 'Light',
            subtitle: 'Always bright',
            icon: Icons.light_mode_rounded,
            selected: current == ThemeMode.light,
            onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.light),
          ),
          const SizedBox(height: 10),
          _ThemeOption(
            label: 'Dark',
            subtitle: 'Easy on the eyes',
            icon: Icons.dark_mode_rounded,
            selected: current == ThemeMode.dark,
            onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accent.withValues(alpha: 0.08)
              : context.appColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.accent : context.appColors.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppTheme.accent : context.appColors.inkMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.appColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  size: 20, color: AppTheme.accent),
          ],
        ),
      ),
    );
  }
}
