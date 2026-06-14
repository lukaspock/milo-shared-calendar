import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

const _kAccent = Color(0xFFF5A623);
const _kBorder = Color(0x17000000); // rgba(26,16,8,0.09)

/// Shared scaffold for every onboarding step (S2–S8).
///
/// Shows: back-arrow circle, dot-progress bar, scrollable content, bottom CTA.
/// S1 (Welcome) and S9 (All Set) render their own Scaffold — no shell needed.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.step,       // 1-based, used to position the filled dot
    required this.totalSteps, // total number of dots shown
    required this.onBack,
    this.customHeader,        // centred at top of form (avatar circle, etc.)
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onContinue,
    required this.child,
    this.isLoading = false,
    this.isSecondaryButton = false,
    this.hideButton = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final Widget? customHeader;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onContinue;
  final Widget child;
  final bool isLoading;
  final bool isSecondaryButton;
  final bool hideButton;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top nav: back + dots ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
              child: Row(
                children: [
                  _BackBtn(onBack: onBack),
                  const SizedBox(width: 14),
                  _ProgDots(step: step, total: totalSteps),
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
                    const SizedBox(height: 32),

                    if (customHeader != null) ...[
                      Center(child: customHeader!),
                      const SizedBox(height: 28),
                    ],

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
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: context.appColors.inkSoft,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    child,
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Pinned bottom CTA ─────────────────────────────────────────────
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: buttonLabel,
                    onPressed: onContinue,
                    isLoading: isLoading,
                    isSecondary: isSecondaryButton,
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onSecondary,
                      child: Center(
                        child: Text(
                          secondaryLabel!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onBack != null
              ? context.appColors.surface
              : context.appColors.surfaceSoft,
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: onBack != null
              ? context.appColors.ink
              : context.appColors.inkMuted,
        ),
      ),
    );
  }
}

// ── Progress dots ─────────────────────────────────────────────────────────────

class _ProgDots extends StatelessWidget {
  const _ProgDots({required this.step, required this.total});
  final int step;  // 1-based current step
  final int total; // total dots

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i == step - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: filled ? 18.0 : 4.0,
          height: 4.0,
          margin: EdgeInsets.only(right: i < total - 1 ? 5.0 : 0),
          decoration: BoxDecoration(
            color: filled ? _kAccent : _kBorder,
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }),
    );
  }
}

// ── Shared icon block used by individual screens ──────────────────────────────

/// Coloured square container with an emoji/icon inside.
/// Matches the handoff spec: 64×64 (or custom size), 20px radius.
class OnboardingIconBlock extends StatelessWidget {
  const OnboardingIconBlock({
    super.key,
    required this.bg,
    required this.child,
    this.size = 64,
    this.radius = 20,
  });

  final Color bg;
  final Widget child;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
