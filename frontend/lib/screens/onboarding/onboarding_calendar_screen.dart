import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_calendar_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_shell.dart';

class OnboardingCalendarScreen extends ConsumerStatefulWidget {
  const OnboardingCalendarScreen({super.key});

  @override
  ConsumerState<OnboardingCalendarScreen> createState() =>
      _OnboardingCalendarScreenState();
}

class _OnboardingCalendarScreenState
    extends ConsumerState<OnboardingCalendarScreen>
    with WidgetsBindingObserver {
  bool _connectingGoogle = false;
  bool _connectingDevice = false;
  bool _deviceConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeviceState();
  }

  Future<void> _loadDeviceState() async {
    final enabled = await DeviceCalendarService().isEnabled();
    if (mounted) setState(() => _deviceConnected = enabled);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh user when returning from Google OAuth browser
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).refreshUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final googleConnected = user?.hasGoogleCalendar == true;
    final anyConnected = googleConnected || _deviceConnected;

    return OnboardingShell(
      step: 4,
      totalSteps: 7,
      onBack: null,
      customHeader: const OnboardingIconBlock(
        bg: Color(0xFFE8F0FF),
        child: Text('📅', style: TextStyle(fontSize: 30)),
      ),
      title: 'Connect your calendars',
      subtitle:
          'Sync your events automatically. Connect one or both — you can always add more later.',
      buttonLabel: anyConnected ? 'Continue' : 'Skip for now',
      onContinue: () => context.go('/onboarding/notifications'),
      isSecondaryButton: !anyConnected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Google Calendar ─────────────────────────────────────────────
          _CalendarOptionCard(
            icon: const Icon(Icons.language_rounded, size: 20, color: Color(0xFF8A7060)),
            title: 'Google Calendar',
            subtitle: 'Sync via your Google account',
            connected: googleConnected,
            connecting: _connectingGoogle,
            connectedLabel: 'Google Calendar connected',
            connectLabel: 'Connect Google Calendar',
            onConnect: () async {
              setState(() => _connectingGoogle = true);
              final url = await ref
                  .read(authProvider.notifier)
                  .getGoogleCalendarConnectUrl();
              if (!mounted) return;
              setState(() => _connectingGoogle = false);
              if (url == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Could not get connect URL. Is backend running?')),
                );
                return;
              }
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
          ),

          const SizedBox(height: 12),

          // ── Device Calendar ─────────────────────────────────────────────
          if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android))
            _CalendarOptionCard(
              icon: const Icon(Icons.phone_iphone_rounded, size: 20, color: Color(0xFF8A7060)),
              title: 'Device Calendar',
              subtitle: 'Sync to your iPhone / Android calendar',
              connected: _deviceConnected,
              connecting: _connectingDevice,
              connectedLabel: 'Device Calendar connected',
              connectLabel: 'Connect Device Calendar',
              onConnect: () async {
                setState(() => _connectingDevice = true);
                final ok = await DeviceCalendarService().connect();
                if (!mounted) return;
                setState(() {
                  _connectingDevice = false;
                  _deviceConnected = ok;
                });
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Could not connect. Please grant calendar permission in Settings.'),
                    ),
                  );
                }
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appColors.line, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, size: 20, color: Color(0xFF8A7060)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Calendar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Only available on iPhone and Android.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.appColors.inkMuted,
                          ),
                        ),
                      ],
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

// ── Reusable calendar option card ─────────────────────────────────────────────

class _CalendarOptionCard extends StatelessWidget {
  const _CalendarOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.connecting,
    required this.connectedLabel,
    required this.connectLabel,
    required this.onConnect,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final bool connected;
  final bool connecting;
  final String connectedLabel;
  final String connectLabel;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFFF0FBF5)
            : context.appColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected
              ? const Color(0xFF1F9D60)
              : context.appColors.line,
          width: connected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: context.appColors.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (connected)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF1F9D60), size: 22),
            ],
          ),

          const SizedBox(height: 12),

          // Connected state or connect button
          if (connected)
            Text(
              connectedLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F5C42),
              ),
            )
          else
            GestureDetector(
              onTap: connecting ? null : onConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 16, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Text(
                            connectLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                            ),
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
