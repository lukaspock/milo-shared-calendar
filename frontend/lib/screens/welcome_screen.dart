import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_sign_in_button.dart';


// ── Apple emoji assets ────────────────────────────────────────────────────────

const _emoji = {
  '📅': 'assets/emoji/calendar.png',
  '🗓️': 'assets/emoji/spiral_cal.png',
  '👥': 'assets/emoji/group.png',
  '⚡': 'assets/emoji/lightning.png',
  '😂': 'assets/emoji/laugh.png',
  '📊': 'assets/emoji/chart.png',
  '📸': 'assets/emoji/camera.png',
  '🔔': 'assets/emoji/bell.png',
  '🍕': 'assets/emoji/pizza.png',
  '🥾': 'assets/emoji/boot.png',
  '❤️': 'assets/emoji/heart.png',
  '🙌': 'assets/emoji/raised_hands.png',
  '☀️': 'assets/emoji/sun.png',
};

Widget _emojiImg(String e, double size) =>
    Image.asset(_emoji[e]!, width: size, height: size);

// ── Handoff design tokens ─────────────────────────────────────────────────────

const _kBg     = Color(0xFFFBF0E3);
const _kSurf   = Color(0xFFF5E8D0);
const _kSurf2  = Color(0xFFEDE0C8);
const _kAccent = Color(0xFFFFB347);
const _kAccent2= Color(0xFFFF9950);
const _kGreen  = Color(0xFF4FA870);
const _kText   = Color(0xFF1F1B16);
const _kText2  = Color(0xFF7A6550);

const _kBgDark    = Color(0xFF1A1610);
const _kSurfDark  = Color(0xFF28231F);
const _kSurf2Dark = Color(0xFF322C27);
const _kText2Dark = Color(0xFF7A6A52);

Color _bg   (BuildContext c) => _isDark(c) ? _kBgDark    : _kBg;
Color _surf (BuildContext c) => _isDark(c) ? _kSurfDark  : _kSurf;
Color _surf2(BuildContext c) => _isDark(c) ? _kSurf2Dark : _kSurf2;
Color _txt  (BuildContext c) => _isDark(c) ? const Color(0xFFF0E8D8) : _kText;
Color _txt2 (BuildContext c) => _isDark(c) ? _kText2Dark : _kText2;
bool  _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

// ── Screen ────────────────────────────────────────────────────────────────────

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    if (isMobile) {
      return _MobileLanding(
        onSignIn: () => context.go('/login'),
        onEmail: () => context.go('/onboarding/email'),
      );
    }

    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LandingNav(),
              _HeroSection(
                onGetStarted: () => context.go('/web-onboarding'),
                onSignIn: () => context.go('/login'),
              ),
              _BuiltForRow(),
              _FeaturesSection(),
              _AvailabilitySection(),
              _GoogleSyncSection(),
              _MiniFeatureGrid(),
              _CtaSection(
                onGetStarted: () => context.go('/web-onboarding'),
                onSignIn: () => context.go('/login'),
              ),
              _LandingFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav ───────────────────────────────────────────────────────────────────────

class _LandingNav extends StatelessWidget {
  const _LandingNav();

  @override
  Widget build(BuildContext context) {
    final border = (_isDark(context) ? Colors.white : Colors.black).withOpacity(0.07);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icons/app_icon.png', width: 30, height: 30),
          ),
          const SizedBox(width: 8),
          Text(
            'milo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w800,
              letterSpacing: -0.5, color: _txt(context),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: Text(
              'Sign in',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w600, color: _txt2(context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _PillButton(
            label: 'Get Started',
            small: true,
            onTap: () => context.go('/web-onboarding'),
          ),
        ],
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onGetStarted, required this.onSignIn});
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 700;
      return wide ? _buildWide(context) : _buildNarrow(context);
    });
  }

  Widget _buildWide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 56, 40, 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: text + CTA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEyebrow(),
                const SizedBox(height: 24),
                Text(
                  'Stay in sync with\nyour people.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 52, fontWeight: FontWeight.w800,
                    color: _txt(context), letterSpacing: -2.5, height: 1.04,
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    'Milo makes it effortless to share your schedule — so you always know when your friends are free, and never miss a plan.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17, fontWeight: FontWeight.w500,
                      color: _txt2(context), height: 1.65,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    _PillButton(
                      label: 'Get Started — it\'s free',
                      large: true,
                      onTap: onGetStarted,
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: onSignIn,
                      child: Text(
                        'Sign in →',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: _txt2(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          // Right: phone + floating chips
          _PhoneWithChips(),
        ],
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildEyebrow(),
          const SizedBox(height: 22),
          Text(
            'Stay in sync with\nyour people.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 42, fontWeight: FontWeight.w800,
              color: _txt(context), letterSpacing: -2.0, height: 1.04,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Milo makes it effortless to share your schedule — so you always know when your friends are free, and never miss a plan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w500,
              color: _txt2(context), height: 1.65,
            ),
          ),
          const SizedBox(height: 40),
          _PhoneMockup(),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: _PillButton(
              label: 'Get Started — it\'s free',
              large: true,
              onTap: onGetStarted,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onSignIn,
            child: Text(
              'Sign in →',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w600, color: _txt2(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEyebrow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: _kAccent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _emojiImg('📅', 14),
          const SizedBox(width: 6),
          Text(
            'Shared calendars for friends',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800,
              letterSpacing: 0.7, color: _kText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneWithChips extends StatelessWidget {
  const _PhoneWithChips();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      height: 600,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Phone mockup centered in the stack
          const Positioned(
            left: 38,
            top: 40,
            child: _PhoneMockup(),
          ),
          // Top-right chip: "Sarah is free Sunday!"
          Positioned(
            right: 0,
            top: 30,
            child: _NotifChip(
              leading: Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  color: _kGreen, shape: BoxShape.circle,
                ),
              ),
              label: 'Sarah is free Sunday!',
            ),
          ),
          // Bottom-left chip: "New event from Jake"
          Positioned(
            left: 0,
            bottom: 28,
            child: _NotifChip(
              leading: _emojiImg('🔔', 14),
              label: 'New event from Jake',
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifChip extends StatelessWidget {
  const _NotifChip({required this.leading, required this.label});
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _isDark(context) ? _kSurfDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kText.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _txt(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phone mockup ──────────────────────────────────────────────────────────────

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup();

  @override
  Widget build(BuildContext context) {
    final phoneBg     = _surf(context);
    final phoneBorder = _surf2(context);
    final innerBg     = _bg(context);
    final textColor   = _txt(context);
    final mutedColor  = _txt2(context);

    return Container(
      width: 264,
      height: 530,
      decoration: BoxDecoration(
        color: phoneBg,
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: phoneBorder, width: 7),
        boxShadow: [
          BoxShadow(
            color: _isDark(context)
                ? Colors.black.withOpacity(0.55)
                : _kText.withOpacity(0.13),
            blurRadius: 80,
            offset: const Offset(0, 40),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Dynamic island
          Center(
            child: Container(
              width: 82,
              height: 22,
              decoration: BoxDecoration(
                color: phoneBorder,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'June 2026',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800, color: textColor,
                        ),
                      ),
                      Row(
                        children: [
                          _PhoneNavBtn('‹', phoneBorder, mutedColor),
                          const SizedBox(width: 4),
                          _PhoneNavBtn('›', phoneBorder, mutedColor),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Weekday labels
                  Row(
                    children: ['S','M','T','W','T','F','S'].map((d) =>
                      Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            color: mutedColor, letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 2),

                  // Calendar grid (June 2026, as in handoff)
                  _StaticCalGrid(textColor: textColor, mutedColor: mutedColor),
                  const SizedBox(height: 10),

                  // Upcoming label
                  Text(
                    'UPCOMING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      letterSpacing: 0.6, color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Events
                  _PhoneEvent(
                    icon: '🍕', iconBg: _kAccent2.withOpacity(0.12),
                    title: 'Dinner & drinks', sub: 'Sun Jun 14 · 7:00 PM',
                    avatarColors: const [Color(0xFFE07030), Color(0xFF5BA87A), Color(0xFF4285F4)],
                    plus: 2, innerBg: innerBg, textColor: textColor, mutedColor: mutedColor,
                    reactions: '😂 ❤️',
                  ),
                  const SizedBox(height: 6),
                  _PhoneEvent(
                    icon: '🥾', iconBg: _kGreen.withOpacity(0.12),
                    title: 'Weekend hike', sub: 'Thu Jun 18 · 9:00 AM',
                    avatarColors: const [Color(0xFF5BA87A), Color(0xFF4285F4)],
                    plus: 0, innerBg: innerBg, textColor: textColor, mutedColor: mutedColor,
                    reactions: '🙌',
                  ),
                  const SizedBox(height: 6),
                  _PhonePollEvent(
                    innerBg: innerBg, textColor: textColor,
                    mutedColor: mutedColor, borderColor: mutedColor.withOpacity(0.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneNavBtn extends StatelessWidget {
  const _PhoneNavBtn(this.label, this.bg, this.color);
  final String label;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 20,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Text(label, style: TextStyle(fontSize: 10, color: color, height: 1.0)),
  );
}

class _StaticCalGrid extends StatelessWidget {
  const _StaticCalGrid({required this.textColor, required this.mutedColor});
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    // June 2026: June 1 is a Sunday (startOffset = 0)
    // Handoff shows full previous-month row above (May 25–31)
    // 0=dim, 1=normal, 2=today(13), 3=ev orange(14,15), 4=ev2 green(18,19)
    const cells = [
      (25,0),(26,0),(27,0),(28,0),(29,0),(30,0),(31,0),
      ( 1,1),( 2,1),( 3,1),( 4,1),( 5,1),( 6,1),( 7,1),
      ( 8,1),( 9,1),(10,1),(11,1),(12,1),(13,2),(14,3),
      (15,3),(16,1),(17,1),(18,4),(19,4),(20,1),(21,1),
      (22,1),(23,1),(24,1),(25,1),(26,1),(27,1),(28,1),
      (29,1),(30,1),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.05,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: cells.map((c) => _CalCell(
        day: c.$1, style: c.$2,
        textColor: textColor, mutedColor: mutedColor,
      )).toList(),
    );
  }
}

class _CalCell extends StatelessWidget {
  const _CalCell({required this.day, required this.style, required this.textColor, required this.mutedColor});
  final int day;
  final int style; // 0=dim,1=normal,2=today,3=ev orange,4=ev green
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (style) {
      case 0: color = mutedColor.withOpacity(0.3); break;
      case 2: color = _kText; break;
      case 3: color = _kAccent2; break;
      case 4: color = _kGreen; break;
      default: color = textColor; break;
    }

    final label = Text(
      '$day',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: style == 2 ? FontWeight.w800 : FontWeight.w500,
        color: color, height: 1.0,
      ),
    );

    if (style == 2) {
      return Center(
        child: Container(
          width: 22, height: 22,
          decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: label,
        ),
      );
    }
    return Center(child: label);
  }
}

class _PhoneEvent extends StatelessWidget {
  const _PhoneEvent({
    required this.icon, required this.iconBg,
    required this.title, required this.sub,
    required this.avatarColors, required this.plus,
    required this.innerBg, required this.textColor, required this.mutedColor,
    this.reactions,
  });
  final String icon;
  final Color iconBg;
  final String title;
  final String sub;
  final List<Color> avatarColors;
  final int plus;
  final Color innerBg;
  final Color textColor;
  final Color mutedColor;
  final String? reactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: innerBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: _emojiImg(icon, 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
                Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 8, color: mutedColor)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniAvatarStack(colors: avatarColors, plus: plus, bgColor: innerBg),
              if (reactions != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions!.runes.map((r) {
                    final ch = String.fromCharCode(r);
                    return _emoji.containsKey(ch)
                        ? Padding(padding: const EdgeInsets.only(left: 1), child: _emojiImg(ch, 11))
                        : const SizedBox.shrink();
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAvatarStack extends StatelessWidget {
  const _MiniAvatarStack({required this.colors, required this.plus, required this.bgColor});
  final List<Color> colors;
  final int plus;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final total = colors.length + (plus > 0 ? 1 : 0);
    return SizedBox(
      width: 6.0 + total * 13.0,
      height: 18,
      child: Stack(
        children: [
          for (int i = 0; i < colors.length; i++)
            Positioned(
              left: i * 13.0,
              child: _AvatarCircle(
                color: colors[i],
                label: ['L','S','J','A'][i.clamp(0,3)],
                bgColor: bgColor,
              ),
            ),
          if (plus > 0)
            Positioned(
              left: colors.length * 13.0,
              child: _AvatarCircle(
                color: const Color(0xFF9B59B6),
                label: '+$plus',
                bgColor: bgColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.color, required this.label, required this.bgColor});
  final Color color;
  final String label;
  final Color bgColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 18, height: 18,
    decoration: BoxDecoration(
      color: color, shape: BoxShape.circle,
      border: Border.all(color: bgColor, width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(label, style: const TextStyle(fontSize: 5.5, color: Colors.white, fontWeight: FontWeight.w700)),
  );
}

class _PhonePollEvent extends StatelessWidget {
  const _PhonePollEvent({
    required this.innerBg, required this.textColor,
    required this.mutedColor, required this.borderColor,
  });
  final Color innerBg;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: borderColor, radius: 10, strokeWidth: 1.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: _kAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
              alignment: Alignment.center,
              child: _emojiImg('📊', 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movie night — vote!', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: mutedColor)),
                  Text('Poll · 3 time options', style: GoogleFonts.plusJakartaSans(fontSize: 8, color: mutedColor)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('Vote →', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: _kAccent2)),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius, required this.strokeWidth});
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
            size.width - strokeWidth, size.height - strokeWidth),
        Radius.circular(radius),
      ));
    const dashW = 4.0, gap = 3.5;
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dashW), paint);
        d += dashW + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter o) => o.color != color || o.radius != radius;
}

// ── Built for ─────────────────────────────────────────────────────────────────

class _BuiltForRow extends StatelessWidget {
  const _BuiltForRow();

  @override
  Widget build(BuildContext context) {
    const items = ['Friend groups','Roommates','Sports teams','Study groups','Weekend crews'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Built for',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: _txt2(context)),
          ),
          ...items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _surf(context),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _surf2(context), width: 1),
            ),
            child: Text(
              item,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: _txt2(context)),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Feature cards ─────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    const cards = [
      ('🗓️', 'Shared group calendars',
       'Create a calendar for any group, invite friends with a code, and stay on the same page — all in one place.'),
      ('👥', 'See who\'s free at a glance',
       'View everyone\'s availability side by side — no more "when are you free?" texts bouncing around the group chat.'),
      ('⚡', 'Real-time everything',
       'Events, reactions and changes land instantly on every device in your group — no refresh needed.'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EyebrowChip(label: 'Everything you need'),
          const SizedBox(height: 14),
          Text(
            'Built around how\nfriends actually plan.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32, fontWeight: FontWeight.w800,
              color: _txt(context), letterSpacing: -1.5, height: 1.1,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: _FeatureCard(icon: cards[i].$1, title: cards[i].$2, body: cards[i].$3)),
                  ],
                ],
              );
            }
            return Column(
              children: cards.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeatureCard(icon: c.$1, title: c.$2, body: c.$3),
              )).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.body});
  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surf2(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _bg(context), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: _emojiImg(icon, 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: _txt(context))),
          const SizedBox(height: 6),
          Text(body, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: _txt2(context), height: 1.6)),
        ],
      ),
    );
  }
}

// ── Availability section ──────────────────────────────────────────────────────

class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection();

  Widget _textSide(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _EyebrowChip(label: 'Availability'),
      const SizedBox(height: 14),
      Text(
        'Know everyone\'s schedule, without asking.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 32, fontWeight: FontWeight.w800,
          color: _txt(context), letterSpacing: -1.5, height: 1.1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Milo pulls in your friends\' calendars — including their Google Calendar events — so you can spot the perfect window for your next plan in seconds.',
        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: _txt2(context), height: 1.65),
      ),
      const SizedBox(height: 16),
      _CheckItem('See free/busy for every group member'),
      const SizedBox(height: 8),
      _CheckItem('Google Calendar events shown alongside Milo events'),
      const SizedBox(height: 8),
      _CheckItem('Highlights windows when everyone overlaps'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 700) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _textSide(context)),
              const SizedBox(width: 48),
              Expanded(child: _AvailabilityVisual()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _textSide(context),
            const SizedBox(height: 24),
            _AvailabilityVisual(),
          ],
        );
      }),
    );
  }
}

class _AvailabilityVisual extends StatelessWidget {
  const _AvailabilityVisual();

  static const _people = [
    ('L', Color(0xFFE07030), 'Lukas', ['Busy','Free','Free','Free','Maybe']),
    ('S', Color(0xFF5BA87A), 'Sarah', ['Free','Free','Busy','Free','Free']),
    ('J', Color(0xFF4285F4), 'Jake',  ['Maybe','Free','Free','Busy','Free']),
    ('A', Color(0xFF9B59B6), 'Amy',   ['Free','Free','Free','Free','Busy']),
  ];
  static const _times = ['Fri eve','Sat AM','Sat PM','Sun AM','Sun PM'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surf2(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who\'s free this weekend?',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: _txt(context)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 86),
              ..._times.map((t) => Expanded(
                child: Text(t, textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w600, color: _txt2(context))),
              )),
            ],
          ),
          const SizedBox(height: 6),
          ..._people.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: p.$2, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(p.$1, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 45,
                  child: Text(p.$3, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _txt(context))),
                ),
                const SizedBox(width: 6),
                ...p.$4.map((slot) => Expanded(child: _avSlot(slot, context))),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.12),
              border: Border.all(color: _kGreen.withOpacity(0.25), width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Everyone\'s free Saturday morning — perfect for a hike!',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _avSlot(String status, BuildContext context) {
  final Color bg;
  final Color textColor;
  switch (status) {
    case 'Free':
      bg = _kGreen.withOpacity(0.18);
      textColor = const Color(0xFF3A8A56);
      break;
    case 'Maybe':
      bg = _kAccent.withOpacity(0.18);
      textColor = const Color(0xFFB08828);
      break;
    default:
      bg = _surf2(context);
      textColor = _txt2(context);
  }
  return Container(
    height: 24,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
    alignment: Alignment.center,
    child: Text(status, style: GoogleFonts.plusJakartaSans(fontSize: 7.5, fontWeight: FontWeight.w700, color: textColor)),
  );
}

class _CheckItem extends StatelessWidget {
  const _CheckItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20, height: 20,
          decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Icon(Icons.check, size: 11, color: _kText),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: _txt(context)),
          ),
        ),
      ],
    );
  }
}

// ── Google Sync section ───────────────────────────────────────────────────────

class _GoogleSyncSection extends StatelessWidget {
  const _GoogleSyncSection();

  Widget _textSide(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _EyebrowChip(label: 'Google Calendar Sync'),
      const SizedBox(height: 14),
      Text(
        'Your whole life in one place.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 32, fontWeight: FontWeight.w800,
          color: _txt(context), letterSpacing: -1.5, height: 1.1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Connect Google Calendar and your work meetings, gym classes, and personal events all flow into Milo automatically — so your friends always see the full picture.',
        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: _txt2(context), height: 1.65),
      ),
      const SizedBox(height: 16),
      _CheckItem('Two-way sync — Milo events appear in Google Calendar too'),
      const SizedBox(height: 8),
      _CheckItem('Works with iOS/Android device calendars too'),
      const SizedBox(height: 8),
      _CheckItem('Refreshes every 5 minutes automatically'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 700) {
          // Flipped: visual on left, text on right
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _GoogleSyncVisual()),
              const SizedBox(width: 48),
              Expanded(child: _textSide(context)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _textSide(context),
            const SizedBox(height: 24),
            _GoogleSyncVisual(),
          ],
        );
      }),
    );
  }
}

class _GoogleSyncVisual extends StatelessWidget {
  const _GoogleSyncVisual();

  static const _events = [
    (Color(0xFFFF9950), 'Dinner & drinks 🍕', 'Sat Jun 14 · 7:00 PM',  'Milo'),
    (Color(0xFF4285F4), 'Team standup',        'Mon Jun 15 · 10:00 AM', 'Google'),
    (Color(0xFF4FA870), 'Weekend hike 🥾',     'Sat Jun 18 · 9:00 AM',  'Milo'),
    (Color(0xFF4285F4), 'Dentist appointment', 'Fri Jun 20 · 2:30 PM',  'Google'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surf2(context), width: 1),
      ),
      child: Column(
        children: [
          // Milo ⇄ Google row
          Row(
            children: [
              Expanded(child: _SyncApp(emoji: '🗓️', name: 'Milo', sub: 'shared calendar',
                  bg: _kAccent.withOpacity(0.15), context: context)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('⇄', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: _kAccent)),
              ),
              Expanded(child: _SyncApp(emoji: '📅', name: 'Google Calendar', sub: 'your personal events',
                  bg: const Color(0xFF4285F4).withOpacity(0.12), context: context)),
            ],
          ),
          const SizedBox(height: 12),
          ..._events.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: _bg(context), borderRadius: BorderRadius.circular(11)),
              child: Row(
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: e.$1, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.$2, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: _txt(context))),
                        Text(e.$3, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _txt2(context))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: e.$4 == 'Milo'
                          ? _kAccent.withOpacity(0.2)
                          : const Color(0xFF4285F4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      e.$4,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: e.$4 == 'Milo' ? const Color(0xFFB08828) : const Color(0xFF4285F4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _SyncApp extends StatelessWidget {
  const _SyncApp({required this.emoji, required this.name, required this.sub, required this.bg, required this.context});
  final String emoji;
  final String name;
  final String sub;
  final Color bg;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg(context),
        border: Border.all(color: _surf2(context), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: _emojiImg(emoji, 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: _txt(context))),
                Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _txt2(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini feature grid ─────────────────────────────────────────────────────────

class _MiniFeatureGrid extends StatelessWidget {
  const _MiniFeatureGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('😂', 'Emoji reactions',    'React to any event — one tap from 8 quick-picks or the full emoji keyboard. Syncs in real time.'),
      ('📊', 'Event polls',        'Propose a few time slots, let everyone vote, and confirm the winner — which auto-creates the event.'),
      ('📸', 'Photo memories',     'Attach photos to any event. Every picture saved where the plan was made.'),
      ('🔔', 'Instant notifications','Email alerts go out to every member the moment a new event is created.'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EyebrowChip(label: 'Even more'),
          const SizedBox(height: 14),
          Text(
            'Small details that\nmake a big difference.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32, fontWeight: FontWeight.w800,
              color: _txt(context), letterSpacing: -1.5, height: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          _miniCardPair(items[0], items[1], context),
          const SizedBox(height: 10),
          _miniCardPair(items[2], items[3], context),
        ],
      ),
    );
  }
}

Widget _miniCardPair(
  (String, String, String) a,
  (String, String, String) b,
  BuildContext context,
) {
  return IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _miniCard(a, context)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard(b, context)),
      ],
    ),
  );
}

Widget _miniCard((String, String, String) item, BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surf(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _surf2(context), width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _emojiImg(item.$1, 32),
        const SizedBox(height: 10),
        Text(item.$2, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: _txt(context))),
        const SizedBox(height: 6),
        Text(item.$3, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: _txt2(context), height: 1.55)),
      ],
    ),
  );
}

// ── CTA ───────────────────────────────────────────────────────────────────────

class _CtaSection extends StatelessWidget {
  const _CtaSection({required this.onGetStarted, required this.onSignIn});
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark(context);
    final boxBg   = isDark ? _kSurfDark : _kText;
    final h2Color = isDark ? _txt(context) : _kBg;
    final subColor = isDark ? _txt2(context) : const Color(0x8CFBF0E3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: boxBg, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to stop\nmissing out?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32, fontWeight: FontWeight.w800,
                color: h2Color, letterSpacing: -1.5, height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Free to use. Just create an account and invite your friends.',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: subColor, height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _PillButton(label: 'Get Started — it\'s free', large: true, onTap: onGetStarted),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: onSignIn,
                child: Text(
                  'Sign in →',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: subColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    final border = (_isDark(context) ? Colors.white : Colors.black).withOpacity(0.07);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: border, width: 1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icons/app_icon.png', width: 22, height: 22),
              ),
              const SizedBox(width: 7),
              Text(
                'milo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: _txt(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _FooterLink(label: 'Privacy', url: 'https://api.milocalendar.tech/privacy'),
              _FooterLink(label: 'Terms',   url: 'https://api.milocalendar.tech/terms'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '© 2026 Milo. Made with ',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _txt2(context), fontWeight: FontWeight.w500),
              ),
              _emojiImg('☀️', 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: _txt2(context)),
    ),
  );
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EyebrowChip extends StatelessWidget {
  const _EyebrowChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _surf(context),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: _surf2(context), width: 1),
    ),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10, fontWeight: FontWeight.w700, color: _txt2(context), letterSpacing: 0.7,
      ),
    ),
  );
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.large = false,
    this.small = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool large;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final pad = large
        ? const EdgeInsets.symmetric(horizontal: 32, vertical: 17)
        : small
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 9)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    final fs = large ? 16.0 : small ? 14.0 : 15.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: large
              ? [BoxShadow(color: _kAccent.withOpacity(0.42), blurRadius: 20, offset: const Offset(0, 8))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: fs, fontWeight: FontWeight.w700, color: _kText),
        ),
      ),
    );
  }
}

// ── Mobile landing (S1 — Welcome) ────────────────────────────────────────────
// Shows logo, eyebrow, title, social-proof pill, and 3 auth buttons directly.
// No progress dots, no back arrow — matches the handoff S1 spec.

class _MobileLanding extends ConsumerStatefulWidget {
  const _MobileLanding({required this.onSignIn, required this.onEmail});
  final VoidCallback onSignIn;
  final VoidCallback onEmail;

  @override
  ConsumerState<_MobileLanding> createState() => _MobileLandingState();
}

class _MobileLandingState extends ConsumerState<_MobileLanding> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.status == AuthStatus.authenticated && mounted) {
        context.go('/onboarding/calendar');
      }
    });

    final isLoading = ref.watch(authProvider).status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/icons/app_icon.png', width: 90, height: 90),
              ),
              const SizedBox(height: 6),

              // Eyebrow
              Text(
                'SHARED CALENDARS FOR FRIENDS',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: const Color(0xFFD88818), letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                'Welcome to milo',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38, fontWeight: FontWeight.w800,
                  color: _txt(context), letterSpacing: -1.5, height: 1.05,
                ),
              ),
              const SizedBox(height: 12),

              // Tagline
              Text(
                'Plan together. See who\'s free.\nNever miss out again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w500,
                  color: _txt2(context), height: 1.55,
                ),
              ),
              const SizedBox(height: 24),

              // Social proof pill
              _MobileSocialProofPill(),

              const Spacer(flex: 3),

              // ── Auth buttons ───────────────────────────────────────────
              GoogleSignInButton(
                isLoading: isLoading,
                onSignedIn: (idToken) =>
                    ref.read(authProvider.notifier).googleSignIn(idToken),
                onError: (e) => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e))),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: widget.onEmail,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kAccent,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: _kAccent.withValues(alpha: 0.38),
                          blurRadius: 20, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Create account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700, color: _kText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: widget.onSignIn,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: _surf2(context), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700, color: _txt(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileAuthBtn extends StatelessWidget {
  const _MobileAuthBtn({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.isLoading,
    required this.leading,
    required this.onTap,
  });
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final bool isLoading;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Simplified Google "G" coloured segments
    final Paint p = Paint()..style = PaintingStyle.fill;

    // Blue segment (right)
    p.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2),
        -0.3, 1.8, true, p);

    // Red segment (top-left)
    p.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2),
        -1.57, 1.3, true, p);

    // Yellow segment (bottom-left)
    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2),
        2.42, 0.7, true, p);

    // Green segment (bottom-right)
    p.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 2),
        3.14, 0.7, true, p);

    // White center circle
    p.color = Colors.white;
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.3, p);

    // White horizontal bar for the "G" cutout
    p.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(s * 0.5, s * 0.38, s * 0.5, s * 0.24), p);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter _) => false;
}

void _showAppleDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Apple Sign-In'),
      content: const Text('Apple Sign-In is not yet implemented.\nUse email or Google for now.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

// ── Mobile social proof pill ──────────────────────────────────────────────────

class _MobileSocialProofPill extends StatelessWidget {
  const _MobileSocialProofPill();

  static const _avatars = [
    ('S', Color(0xFF5BA87A)),
    ('J', Color(0xFF4285F4)),
    ('A', Color(0xFF9B59B6)),
    ('L', Color(0xFFE07030)),
  ];

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 18.0;
    final totalWidth = size + (_avatars.length - 1) * overlap;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark(context) ? _kSurfDark : Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: _kText.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: totalWidth,
            height: size,
            child: Stack(
              children: [
                for (int i = 0; i < _avatars.length; i++)
                  Positioned(
                    left: i * overlap,
                    child: Container(
                      width: size, height: size,
                      decoration: BoxDecoration(
                        color: _avatars[i].$2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isDark(context) ? _kSurfDark : Colors.white,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _avatars[i].$1,
                        style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Sync your friend groups',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: _txt(context),
            ),
          ),
        ],
      ),
    );
  }
}

