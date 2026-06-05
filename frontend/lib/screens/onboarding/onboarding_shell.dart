import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

/// Shared scaffold for every onboarding step.
///
/// Provides: back button, progress bar, illustration, title/subtitle,
/// scrollable [child] content area, and a bottom [buttonLabel] button.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onBack,
    this.illustration,
    this.illustrationHue,
    this.customHeader,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onContinue,
    required this.child,
    this.isLoading = false,
    this.isSecondaryButton = false,
    this.hideButton = false,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final Widget? illustration;
  final CalHue? illustrationHue;
  final Widget? customHeader;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onContinue;
  final Widget child;
  final bool isLoading;
  final bool isSecondaryButton;
  /// When true the bottom button is hidden entirely (the child provides its own actions).
  final bool hideButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar: back + progress ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: Row(
                children: [
                  _BackButton(onBack: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: step / totalSteps,
                        minHeight: 5,
                        backgroundColor: context.appColors.line,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 36),

                    // Illustration or custom header
                    if (customHeader != null) ...[
                      Center(child: customHeader!),
                      const SizedBox(height: 36),
                    ] else if (illustration != null && illustrationHue != null) ...[
                      Center(
                        child: StickerTile(
                          hue: illustrationHue!,
                          size: 140,
                          radius: 36,
                          child: illustration!,
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],

                    // Title
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.ink,
                        letterSpacing: -1,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: context.appColors.inkSoft,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Step-specific content
                    child,

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Pinned bottom button (hidden when the child owns its actions) ──
      bottomNavigationBar: hideButton
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                12,
                28,
                MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    16,
              ),
              child: AppButton(
                label: buttonLabel,
                onPressed: onContinue,
                isLoading: isLoading,
                isSecondary: isSecondaryButton,
              ),
            ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onBack != null ? context.appColors.surface : context.appColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appColors.line, width: 1.5),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: onBack != null ? context.appColors.ink : context.appColors.inkMuted,
        ),
      ),
    );
  }
}
