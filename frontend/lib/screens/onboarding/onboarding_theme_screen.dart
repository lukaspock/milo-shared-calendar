import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import 'onboarding_shell.dart';

/// S8 — Choose your look (theme picker with split-swatch previews).
class OnboardingThemeScreen extends ConsumerWidget {
  const OnboardingThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    return OnboardingShell(
      step: 7,
      totalSteps: 7,
      onBack: () => context.go('/onboarding/avatar'),
      customHeader: const OnboardingIconBlock(
        bg: Color(0xFFEDE8FF),
        child: Text('🌙', style: TextStyle(fontSize: 30)),
      ),
      title: 'Choose your look',
      subtitle: 'Pick a theme. You can change it any time in Settings.',
      buttonLabel: 'Continue',
      onContinue: () => context.go('/onboarding/ready'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ThemeRow(
            label: 'System default',
            sub: 'Follows your device setting',
            leftColor: const Color(0xFFFAF3ED),
            rightColor: const Color(0xFF1A1208),
            selected: current == ThemeMode.system,
            onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.system),
          ),
          const SizedBox(height: 10),
          _ThemeRow(
            label: 'Light',
            sub: 'Always bright',
            leftColor: const Color(0xFFFAF3ED),
            rightColor: const Color(0xFFFAF3ED),
            selected: current == ThemeMode.light,
            onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.light),
          ),
          const SizedBox(height: 10),
          _ThemeRow(
            label: 'Dark',
            sub: 'Easy on the eyes',
            leftColor: const Color(0xFF1A1208),
            rightColor: const Color(0xFF1A1208),
            selected: current == ThemeMode.dark,
            onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.label,
    required this.sub,
    required this.leftColor,
    required this.rightColor,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String sub;
  final Color leftColor;
  final Color rightColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x20F5A623)
              : context.appColors.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFF5A623) : context.appColors.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Split-colour swatch
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 36,
                child: Row(
                  children: [
                    Expanded(child: Container(color: leftColor)),
                    Expanded(child: Container(color: rightColor)),
                  ],
                ),
              ),
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
                    sub,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.appColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppTheme.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.accent : context.appColors.line,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
