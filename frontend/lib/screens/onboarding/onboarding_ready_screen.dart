import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

/// S9 — You're all set (no shell, no dots, no back arrow).
class OnboardingReadyScreen extends ConsumerStatefulWidget {
  const OnboardingReadyScreen({super.key});

  @override
  ConsumerState<OnboardingReadyScreen> createState() =>
      _OnboardingReadyScreenState();
}

class _OnboardingReadyScreenState extends ConsumerState<OnboardingReadyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final firstName = user?.name.split(' ').first ?? 'there';
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1916)
        : const Color(0xFFFAF3ED);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Confetti + party emoji
              SizedBox(
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const _Confetti(),
                    ScaleTransition(
                      scale: _pulse,
                      child: const Text('🎉', style: TextStyle(fontSize: 72)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                "You're all set,\n$firstName!",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF0E8D8)
                      : const Color(0xFF1A1008),
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Milo is ready to help you plan and connect with the people that matter.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  color: const Color(0xFF8A7060),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Checklist cards
              _CheckCard(emoji: '✅', label: 'Account created'),
              const SizedBox(height: 8),
              _CheckCard(emoji: '📅', label: 'Google Calendar synced'),
              const SizedBox(height: 8),
              _CheckCard(emoji: '🔔', label: 'Notifications on'),

              const Spacer(flex: 3),

              // Amber CTA
              Container(
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.35),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF1A1008),
                    minimumSize: const Size(double.infinity, 58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'Start planning →',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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

// ── Checklist card ────────────────────────────────────────────────────────────

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.emoji, required this.label});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF28231F)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x17000000), width: 1.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF0E8D8)
                    : const Color(0xFF1A1008),
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4FA870),
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ── Confetti animation ────────────────────────────────────────────────────────

class _Confetti extends StatefulWidget {
  const _Confetti();

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _particles = [
    _P(x: 0.15, color: Color(0xFFF5A623), shape: true, delay: 0.0, dur: 1.6),
    _P(x: 0.28, color: Color(0xFFF06292), shape: false, delay: 0.2, dur: 2.0),
    _P(x: 0.42, color: Color(0xFF4285F4), shape: true, delay: 0.4, dur: 1.4),
    _P(x: 0.55, color: Color(0xFF4FA870), shape: false, delay: 0.6, dur: 1.8),
    _P(x: 0.68, color: Color(0xFF9B59B6), shape: true, delay: 0.8, dur: 2.2),
    _P(x: 0.80, color: Color(0xFFEF5350), shape: false, delay: 1.0, dur: 1.5),
    _P(x: 0.10, color: Color(0xFFFBBC05), shape: true, delay: 0.3, dur: 1.9),
    _P(x: 0.35, color: Color(0xFF26C6A4), shape: false, delay: 0.9, dur: 1.7),
    _P(x: 0.50, color: Color(0xFFFF7043), shape: true, delay: 1.2, dur: 2.1),
    _P(x: 0.72, color: Color(0xFF42A5F5), shape: false, delay: 0.5, dur: 1.6),
    _P(x: 0.90, color: Color(0xFF66BB6A), shape: true, delay: 1.5, dur: 1.4),
    _P(x: 0.22, color: Color(0xFFAB47BC), shape: false, delay: 0.7, dur: 2.0),
    _P(x: 0.60, color: Color(0xFFF5A623), shape: true, delay: 1.1, dur: 1.8),
    _P(x: 0.85, color: Color(0xFFF06292), shape: false, delay: 1.8, dur: 1.5),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return SizedBox(
          width: double.infinity,
          height: 100,
          child: Stack(
            children: _particles.map((p) {
              final raw = (_ctrl.value - p.delay / 2.2).clamp(0.0, 1.0);
              final t = raw / (p.dur / 2.2);
              final y = -20.0 + t * 80.0;
              final op = 1.0 - t;
              return Positioned(
                left: MediaQuery.sizeOf(context).width * p.x,
                top: 10 + y,
                child: Opacity(
                  opacity: op.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: t * 6.28,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: p.shape ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: p.shape ? BorderRadius.circular(2) : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _P {
  final double x, delay, dur;
  final Color color;
  final bool shape; // true = square, false = circle
  const _P({
    required this.x,
    required this.color,
    required this.shape,
    required this.delay,
    required this.dur,
  });
}
