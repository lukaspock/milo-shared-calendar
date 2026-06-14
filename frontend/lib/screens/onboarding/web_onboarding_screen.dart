import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/local_notification_service.dart';
import '../../models/user.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kBg     = Color(0xFFFAF3ED);
const _kSurf   = Color(0xFFF0E4D4);
const _kSurf2  = Color(0xFFE5D5C0);
const _kText   = Color(0xFF1A1008);
const _kText2  = Color(0xFF8A7060);
const _kAccent = Color(0xFFF5A623);
const _kAccdk  = Color(0xFFD88818);
const _kGreen  = Color(0xFF4FA870);
const _kBorder = Color(0x17000000);
const _kPanelBg   = Color(0xFF1A1008);
const _kPanelText = Color(0xFFF0E8D8);
const _kPanelMuted= Color(0xFF7A6A52);


// ── Avatar colours (S7) ───────────────────────────────────────────────────────
const _avatarColors = [
  Color(0xFF7B68EE), Color(0xFFF06292), Color(0xFF26C6A4), Color(0xFFFFB300),
  Color(0xFF42A5F5), Color(0xFFEF5350), Color(0xFF66BB6A), Color(0xFFAB47BC),
];

/// 9-step web onboarding — split-panel layout.
/// Left panel: dark brand panel with contextual visual.
/// Right panel: cream form panel with step content.
class WebOnboardingScreen extends ConsumerStatefulWidget {
  const WebOnboardingScreen({super.key});

  @override
  ConsumerState<WebOnboardingScreen> createState() => _WebOnboardingScreenState();
}

class _WebOnboardingScreenState extends ConsumerState<WebOnboardingScreen> {
  int _step = 0; // 0-based (0=Welcome … 8=AllSet)

  // Form state
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure       = true;
  bool _googleConnected = false;
  bool _notifPush     = false; // push not available on web
  bool _notifEmail    = false;
  int  _colorIndex    = 3; // FFB300 selected by default
  String? _webAvatarUrl;
  bool _uploadingAvatar = false;
  Timer? _verifyTimer;
  bool _resent = false;

  // Loading/error
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _verifyTimer?.cancel();
    super.dispose();
  }

  void _goNext() => setState(() { _step = (_step + 1).clamp(0, 8); _error = null; });
  void _goBack() => setState(() { _step = (_step - 1).clamp(0, 8); _error = null; });

  void _goHome() => context.go('/home');

  // ── S1: Auth button handlers ───────────────────────────────────────────────
  void _onEmail() => _goNext(); // go to S2

  void _onSignIn() => context.go('/welcome'); // ← Back to site

  void _onLogin() => context.go('/login'); // Already have an account

  // ── S2: Create account → S3 ───────────────────────────────────────────────
  void _submitNameEmail() {
    if (_nameCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Please fill in both fields correctly.');
      return;
    }
    ref.read(onboardingProvider.notifier)
        .setNameEmail(_nameCtrl.text.trim(), _emailCtrl.text.trim());
    _goNext();
  }

  // ── S3: Create account (register) → S4 ────────────────────────────────────
  Future<void> _register() async {
    if (_passwordCtrl.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final data = ref.read(onboardingProvider);
    await ref.read(authProvider.notifier).register(
      data.email, _passwordCtrl.text, data.name,
    );
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.error != null) {
      setState(() { _loading = false; _error = authState.error; });
    } else {
      setState(() => _loading = false);
      _startVerifyPolling();
      _goNext();
    }
  }

  // ── S4: Verify — poll for verification ────────────────────────────────────
  void _startVerifyPolling() {
    _verifyTimer?.cancel();
    _verifyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshUser();
      final user = ref.read(authProvider).user;
      if (user?.emailVerified == true) {
        _verifyTimer?.cancel();
        setState(() => _step = 4); // jump to S5
      }
    });
  }

  Future<void> _resendEmail() async {
    await ref.read(authProvider.notifier).resendVerification();
    if (mounted) setState(() => _resent = true);
  }

  // ── S5: Google Calendar connect ────────────────────────────────────────────
  Future<void> _connectGoogle() async {
    setState(() => _loading = true);
    final url = await ref.read(authProvider.notifier).getGoogleCalendarConnectUrl();
    setState(() => _loading = false);
    if (url != null && mounted) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      final user = ref.read(authProvider).user;
      if (mounted && user?.hasGoogleCalendar == true) {
        setState(() => _googleConnected = true);
      }
    }
  }

  // ── S6: Save notification prefs ────────────────────────────────────────────
  Future<void> _saveNotifs() async {
    setState(() => _loading = true);
    if (_notifPush) await LocalNotificationService().requestPermission();
    final type = _notifEmail ? NotificationType.email : NotificationType.push;
    await ref.read(authProvider.notifier).updateNotificationType(type);
    setState(() => _loading = false);
    _goNext();
  }

  // ── S7: Avatar photo picker ────────────────────────────────────────────────
  Future<void> _pickWebPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512, maxHeight: 512, imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ApiService().uploadAvatarToCloudinary(picked);
      if (mounted) setState(() { _webAvatarUrl = url; _uploadingAvatar = false; });
    } on CloudinaryUploadException catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
      }
    }
  }

  // ── S7: Save colour (+ avatar if picked) ──────────────────────────────────
  Future<void> _saveColor() async {
    setState(() => _loading = true);
    final hex = '#${_avatarColors[_colorIndex].value.toRadixString(16).substring(2).toUpperCase()}';
    await ref.read(authProvider.notifier).updateProfile(
      color: hex,
      avatarUrl: _webAvatarUrl,
    );
    setState(() => _loading = false);
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, state) {
      if (!mounted) return;
      // Google sign-in on S0 → skip name/password/verify, go to calendar connect
      if (state.status == AuthStatus.authenticated && _step == 0) {
        setState(() { _step = 4; _loading = false; });
        return;
      }
      // Auto-advance when email verified
      if (state.user?.emailVerified == true && _step == 3) {
        _verifyTimer?.cancel();
        setState(() => _step = 4);
      }
    });

    final screenW = MediaQuery.sizeOf(context).width;
    final narrow  = screenW < 700;

    return Scaffold(
      backgroundColor: _step == 8 ? _kBg : _kPanelBg,
      body: narrow
          ? _buildNarrowFallback(context)
          : _step == 8
              ? _buildFinalFullScreen(context)
              : _buildSplitPanel(context),
    );
  }

  // ── Narrow fallback (redirect to mobile onboarding) ───────────────────────
  Widget _buildNarrowFallback(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/onboarding/email');
    });
    return const SizedBox.shrink();
  }

  // ── S9: Full-width centered celebration screen ────────────────────────────
  Widget _buildFinalFullScreen(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
            child: _buildS9(context),
          ),
        ),
      ),
    );
  }

  // ── Full split panel ──────────────────────────────────────────────────────
  Widget _buildSplitPanel(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left dark panel
        Expanded(child: _LeftPanel(step: _step, colorIndex: _colorIndex)),
        // Right cream panel
        Expanded(child: _buildRightPanel(context)),
      ],
    );
  }

  // ── Right panel ───────────────────────────────────────────────────────────
  Widget _buildRightPanel(BuildContext context) {
    final showBack = _step > 0 && _step < 8;
    final showDots = _step >= 1 && _step <= 7;

    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigation chrome
          Row(
            children: [
              if (showBack)
                GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _kSurf,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBorder, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back_rounded, size: 16, color: _kText),
                  ),
                )
              else
                const SizedBox(width: 34),
              const SizedBox(width: 12),
              if (showDots) _WebProgDots(step: _step - 1, total: 7),
              const Spacer(),
              if (_step == 0)
                GestureDetector(
                  onTap: _onSignIn,
                  child: Text(
                    '← Back to site',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: _kText2,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 32),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              child: _buildStepContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case 0: return _buildS1(context);
      case 1: return _buildS2(context);
      case 2: return _buildS3(context);
      case 3: return _buildS4(context);
      case 4: return _buildS5(context);
      case 5: return _buildS6(context);
      case 6: return _buildS7(context);
      case 7: return _buildS8(context);
      case 8: return _buildS9(context);
      default: return const SizedBox.shrink();
    }
  }

  // ── S1: Welcome ───────────────────────────────────────────────────────────
  Widget _buildS1(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('GET STARTED FOR FREE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: _kAccdk, letterSpacing: 0.07 * 11,
            )),
        const SizedBox(height: 10),
        Text('Welcome to milo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40, fontWeight: FontWeight.w800,
              color: _kText, letterSpacing: -1.5, height: 1.1,
            )),
        const SizedBox(height: 10),
        Text('Plan together. See who\'s free. Never miss out again.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17, color: _kText2, height: 1.65,
            )),
        const SizedBox(height: 28),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Google button — uses renderButton from Google GIS SDK on web
                GoogleSignInButton(
                  isLoading: _loading,
                  onSignedIn: (idToken) {
                    setState(() => _loading = true);
                    ref.read(authProvider.notifier).googleSignIn(idToken).whenComplete(
                      () { if (mounted) setState(() => _loading = false); },
                    );
                  },
                  onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e)),
                  ),
                ),
                const SizedBox(height: 10),
                // Apple button
                _WebAuthBtn(
                  label: 'Continue with Apple',
                  bg: _kText,
                  textColor: _kBg,
                  border: Colors.transparent,
                  leading: Icon(Icons.apple, size: 20, color: _kBg),
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                // Email button
                _WebAuthBtn(
                  label: 'Continue with email',
                  bg: Colors.transparent,
                  textColor: _kText2,
                  border: _kBorder,
                  leading: const Icon(Icons.mail_outline_rounded, size: 18, color: _kText2),
                  onTap: _onEmail,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Center(
          child: GestureDetector(
            onTap: _onLogin,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kText2),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Sign in',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _kAccdk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── S2: Create account ────────────────────────────────────────────────────
  Widget _buildS2(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WebScreenTitle('Create your account'),
        const SizedBox(height: 24),
        _WebField(controller: _nameCtrl, hint: 'Full name',
            icon: Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _WebField(controller: _emailCtrl, hint: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        Text(
          'By continuing you agree to our Terms of Service and Privacy Policy.',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kText2, height: 1.4),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.red)),
        ],
        const SizedBox(height: 24),
        _WebPrimaryBtn(label: 'Continue', onTap: _submitNameEmail),
      ],
    );
  }

  // ── S3: Password ──────────────────────────────────────────────────────────
  Widget _buildS3(BuildContext context) {
    final len = _passwordCtrl.text.length;
    final strength = len == 0 ? 0 : len < 8 ? 1 : len < 12 ? 2 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WebScreenTitle('Create a password'),
        const SizedBox(height: 24),
        _WebField(
          controller: _passwordCtrl,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          onChanged: (_) => setState(() {}),
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18, color: _kText2,
            ),
          ),
        ),
        if (strength > 0) ...[
          const SizedBox(height: 8),
          _WebStrengthMeter(strength: strength),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.red)),
        ],
        const SizedBox(height: 24),
        _WebPrimaryBtn(
          label: 'Create account',
          onTap: _loading ? null : _register,
          loading: _loading,
        ),
      ],
    );
  }

  // ── S4: Verify email ──────────────────────────────────────────────────────
  Widget _buildS4(BuildContext context) {
    final email = ref.watch(authProvider).user?.email ?? _emailCtrl.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D0),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Text('📬', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 20),
        _WebScreenTitle('Check your inbox'),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _kText2, height: 1.5),
            children: [
              const TextSpan(text: 'We sent a verification link to '),
              TextSpan(text: email,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _kText)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Waiting pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D0),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFFE5B130), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFD88818),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Waiting for verification…',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _kAccdk,
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _resent ? null : _resendEmail,
            child: Text(
              _resent ? '✓ Email resent!' : 'Resend email',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: _resent ? _kGreen : _kAccdk,
                decoration: _resent ? null : TextDecoration.underline,
                decorationColor: _kAccdk,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _WebOutlineBtn(label: 'Skip for now', onTap: _goNext),
      ],
    );
  }

  // ── S5: Connect calendars ─────────────────────────────────────────────────
  Widget _buildS5(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final connected = _googleConnected || (user?.hasGoogleCalendar == true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WebScreenTitle('Connect your calendars'),
        const SizedBox(height: 20),
        // Google Calendar card
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: connected ? _kAccent.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected ? _kAccent : _kBorder, width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('📅', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Calendar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _kText,
                        )),
                    Text('Sync via your Google account',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kText2)),
                  ],
                ),
              ),
              if (connected)
                const Icon(Icons.check_circle_rounded, color: _kGreen, size: 22)
              else
                GestureDetector(
                  onTap: _loading ? null : _connectGoogle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kAccdk, width: 1.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '+ Connect',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kAccdk,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Device calendar (static)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E4D4),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.phone_iphone_rounded, size: 20, color: _kText2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Calendar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _kText,
                        )),
                    Text('Available on iPhone & Android',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kText2)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (connected)
          _WebPrimaryBtn(label: 'Continue →', onTap: _goNext)
        else
          _WebOutlineBtn(label: 'Skip for now', onTap: _goNext),
      ],
    );
  }

  // ── S6: Notifications ─────────────────────────────────────────────────────
  Widget _buildS6(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WebScreenTitle('Stay in the loop'),
        const SizedBox(height: 20),
        _WebNotifRow(
          emoji: '🔔',
          title: 'On my device',
          sub: 'Available on iOS & Android',
          selected: false,
          disabled: true,
          onTap: () {},
        ),
        const SizedBox(height: 10),
        _WebNotifRow(
          emoji: '✉️',
          title: 'Email',
          sub: 'Get an email each time',
          selected: _notifEmail,
          onTap: () => setState(() => _notifEmail = !_notifEmail),
        ),
        const SizedBox(height: 24),
        _WebPrimaryBtn(
          label: 'Continue',
          onTap: _loading ? null : _saveNotifs,
          loading: _loading,
        ),
      ],
    );
  }

  // ── S7: Make it yours ─────────────────────────────────────────────────────
  Widget _buildS7(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final initial = (user?.name ?? _nameCtrl.text).isNotEmpty
        ? (user?.name ?? _nameCtrl.text).trim()[0].toUpperCase()
        : 'L';
    final color = _avatarColors[_colorIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Avatar preview
        Center(
          child: GestureDetector(
            onTap: _uploadingAvatar ? null : _pickWebPhoto,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 2.5),
                      boxShadow: [
                        BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 3),
                        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 6),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _uploadingAvatar
                        ? CircularProgressIndicator(color: color, strokeWidth: 2.5)
                        : _webAvatarUrl != null
                            ? ClipOval(child: Image.network(_webAvatarUrl!, width: 72, height: 72, fit: BoxFit.cover))
                            : Text(initial,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28, fontWeight: FontWeight.w700, color: color)),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBg, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _uploadingAvatar ? 'Uploading…' : _webAvatarUrl != null ? 'Tap to change photo' : 'Tap to add a photo',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kText2),
          ),
        ),
        const SizedBox(height: 20),
        _WebScreenTitle('Make it yours'),
        const SizedBox(height: 16),
        // 8-colour swatch row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_avatarColors.length, (i) {
            final c = _avatarColors[i];
            final sel = i == _colorIndex;
            return GestureDetector(
              onTap: () => setState(() => _colorIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: sel ? 38 : 34,
                height: sel ? 38 : 34,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? _kText : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: c.withValues(alpha: 0.44), blurRadius: 8)]
                      : null,
                ),
                alignment: Alignment.center,
                child: sel
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        _WebPrimaryBtn(label: 'Save & continue', onTap: _loading ? null : _saveColor, loading: _loading),
        const SizedBox(height: 10),
        _WebOutlineBtn(label: 'Skip for now', onTap: _goNext),
      ],
    );
  }

  // ── S8: Choose your look ──────────────────────────────────────────────────
  Widget _buildS8(BuildContext context) {
    final current = ref.watch(themeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WebScreenTitle('Choose your look'),
        const SizedBox(height: 20),
        _WebThemeRow(
          label: 'System default', sub: 'Follows your device setting',
          left: const Color(0xFFFAF3ED), right: const Color(0xFF1A1208),
          selected: current == ThemeMode.system,
          onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.system),
        ),
        const SizedBox(height: 10),
        _WebThemeRow(
          label: 'Light', sub: 'Always bright',
          left: const Color(0xFFFAF3ED), right: const Color(0xFFFAF3ED),
          selected: current == ThemeMode.light,
          onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.light),
        ),
        const SizedBox(height: 10),
        _WebThemeRow(
          label: 'Dark', sub: 'Easy on the eyes',
          left: const Color(0xFF1A1208), right: const Color(0xFF1A1208),
          selected: current == ThemeMode.dark,
          onTap: () => ref.read(themeProvider.notifier).setMode(ThemeMode.dark),
        ),
        const SizedBox(height: 24),
        _WebPrimaryBtn(label: 'Continue', onTap: _goNext),
      ],
    );
  }

  // ── S9: All set ───────────────────────────────────────────────────────────
  Widget _buildS9(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = (user?.name ?? _nameCtrl.text).split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Confetti + emoji
        SizedBox(
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: const [
              _WebConfetti(),
              Text('🎉', style: TextStyle(fontSize: 60)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text("You're all set,\n$name!",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 38, fontWeight: FontWeight.w800,
              color: _kText, letterSpacing: -1.5, height: 1.1,
            )),
        const SizedBox(height: 20),
        _WebCheckRow('✅', 'Account created'),
        const SizedBox(height: 8),
        _WebCheckRow('📅', 'Google Calendar synced'),
        const SizedBox(height: 8),
        _WebCheckRow('🔔', 'Notifications on'),
        const SizedBox(height: 28),
        _WebAccentBtn(label: 'Start planning →', onTap: _goHome),
      ],
    );
  }
}

// ── Left panel ────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.step, required this.colorIndex});
  final int step;
  final int colorIndex;

  static const _headlines = [
    'Plan together.\nMiss nothing.',
    'You\'re almost\nin the loop.',
    'Keep your\nschedule safe.',
    'Almost there!',
    'See the full\npicture.',
    'Never miss\na plan again.',
    'Stand out\nin the crowd.',
    'Your eyes,\nyour rules.',
    'You\'re in\nthe group! 🎉',
  ];
  static const _subs = [
    'The shared calendar for\nyour friend group.',
    'Create your account\nand get started.',
    'Your data stays\nsafe and private.',
    'Check your inbox\nfor the link.',
    'Connect your calendars\nand see everyone\'s plans.',
    'Stay updated on\nevery new event.',
    'Pick your colour\nso friends know it\'s you.',
    'Choose how\nMilo looks for you.',
    'Your group is\nwaiting for you!',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kPanelBg,
      padding: const EdgeInsets.fromLTRB(48, 52, 48, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/icons/app_icon.png', width: 34, height: 34),
              ),
              const SizedBox(width: 10),
              Text('milo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 21, fontWeight: FontWeight.w800,
                    color: _kPanelText, letterSpacing: -0.5,
                  )),
            ],
          ),
          const SizedBox(height: 48),

          // Headline
          Text(
            _headlines[step.clamp(0, 8)],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 42, fontWeight: FontWeight.w800,
              color: _kPanelText, letterSpacing: -2, height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _subs[step.clamp(0, 8)],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15, color: _kPanelMuted, height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          // Contextual visual
          Expanded(child: _LeftVisual(step: step, colorIndex: colorIndex)),

          const SizedBox(height: 24),
          // Step indicator
          if (step > 0 && step < 8)
            Text(
              'Step ${step} of 8',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: _kPanelMuted,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Left contextual visuals per step ─────────────────────────────────────────

class _LeftVisual extends StatelessWidget {
  const _LeftVisual({required this.step, required this.colorIndex});
  final int step;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:  return _LeftCalendar();
      case 1:  return _LeftFriendList();
      case 5:  return _LeftNotifFeed();
      case 6:  return _LeftColorPicker(colorIndex: colorIndex);
      case 7:  return _LeftThemePreview();
      case 8:  return _LeftChecklist();
      default: return const SizedBox.shrink();
    }
  }
}

// S1 — Mini calendar widget
class _LeftCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const cellStyle = TextStyle(fontSize: 11, color: _kPanelText);
    const days = ['S','M','T','W','T','F','S'];
    const weeks = [
      [' ',' ',' ','1','2','3','4'],
      ['5','6','7','8','9','10','11'],
      ['12','13','14','15','16','17','18'],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('June 2026',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w800, color: _kPanelText,
              )),
          const SizedBox(height: 10),
          Row(
            children: days.map((d) => Expanded(
              child: Text(d, textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 9, color: _kPanelMuted)),
            )).toList(),
          ),
          const SizedBox(height: 4),
          ...weeks.map((week) => Row(
            children: week.map((d) {
              final isToday = d == '5';
              final isEvent = d == '6' || d == '7';
              return Expanded(
                child: Container(
                  height: 26,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(1),
                  decoration: isToday
                      ? const BoxDecoration(color: _kAccent, shape: BoxShape.circle)
                      : isEvent
                          ? BoxDecoration(
                              color: const Color(0x30F5A623),
                              borderRadius: BorderRadius.circular(6),
                            )
                          : null,
                  child: Text(d,
                      style: isToday
                          ? GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: _kText)
                          : d == ' '
                              ? const TextStyle()
                              : cellStyle),
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x30F5A623),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🍕', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dinner & drinks',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _kPanelText,
                        )),
                    Text('Sat Jun 6 · 7:00 PM',
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kPanelMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// S2 — Friend list
class _LeftFriendList extends StatelessWidget {
  static const _friends = [
    ('S', Color(0xFFE07030), 'Sarah', true),
    ('J', Color(0xFF4285F4), 'Jake',  true),
    ('A', Color(0xFF4FA870), 'Amy',   false),
    ('L', Color(0xFFFFB300), 'Lukas', true),
    ('M', Color(0xFF9B59B6), 'Mia',   false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Column(
        children: _friends.asMap().entries.map((e) {
          final f = e.value;
          return Padding(
            padding: EdgeInsets.only(bottom: e.key < _friends.length - 1 ? 10 : 0),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: f.$2, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(f.$1,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(f.$3,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kPanelText,
                      )),
                ),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: f.$4 ? _kGreen : _kPanelMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// S6 — Notification feed
class _LeftNotifFeed extends StatelessWidget {
  static const _notifs = [
    ('🍕', Color(0xFFF5A623), 'Dinner & drinks', '2 min ago'),
    ('🥾', Color(0xFF4FA870), 'Weekend hike',    '1 hr ago'),
    ('📊', Color(0xFF9B59B6), 'Movie night poll', '3 hr ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _notifs.asMap().entries.map((e) {
        final n = e.value;
        return Padding(
          padding: EdgeInsets.only(bottom: e.key < _notifs.length - 1 ? 10 : 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: n.$2.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(n.$1, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.$3,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _kPanelText,
                          )),
                      Text(n.$4,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kPanelMuted)),
                    ],
                  ),
                ),
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: n.$2, shape: BoxShape.circle)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// S7 — Colour picker preview
class _LeftColorPicker extends StatelessWidget {
  const _LeftColorPicker({required this.colorIndex});
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(_avatarColors.length, (i) {
            final c = _avatarColors[i];
            final sel = i == colorIndex;
            return Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2.5),
              ),
              alignment: Alignment.center,
              child: sel ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            );
          }),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _avatarColors[colorIndex].withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            alignment: Alignment.center,
            child: Text('L',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _avatarColors[colorIndex],
                )),
          ),
        ),
      ],
    );
  }
}

// S8 — Theme preview
class _LeftThemePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _ThemeCard(bg: const Color(0xFFFAF3ED), label: 'Light')),
        const SizedBox(width: 12),
        Expanded(child: _ThemeCard(bg: const Color(0xFF0D0A05), label: 'Dark')),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.bg, required this.label});
  final Color bg;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDk = bg.computeLuminance() < 0.5;
    final ink     = isDk ? const Color(0xFFF0E8D8) : const Color(0xFF1A1008);
    final muted   = isDk ? const Color(0xFF7A6A52) : const Color(0xFF8A7060);
    final surface = isDk ? const Color(0xFF2A2018) : const Color(0xFFF0E4D4);

    const weeks = [
      [' ',' ',' ',' ',' ',' ','1'],
      ['2','3','4','5','6','7','8'],
      ['9','10','11','12','13','14','15'],
      ['16','17','18','19','20','21','22'],
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x20000000), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Calendar header ────────────────────────────────────────────
          Row(children: [
            Text('June 2026', style: GoogleFonts.plusJakartaSans(
              fontSize: 8, fontWeight: FontWeight.w800, color: ink)),
            const Spacer(),
            Icon(Icons.chevron_left_rounded,  size: 10, color: muted),
            Icon(Icons.chevron_right_rounded, size: 10, color: muted),
          ]),
          const SizedBox(height: 5),
          // ── Day abbreviations ──────────────────────────────────────────
          Row(children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
            child: Text(d, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 5.5, color: muted, fontWeight: FontWeight.w600)),
          )).toList()),
          const SizedBox(height: 2),
          // ── Calendar grid ──────────────────────────────────────────────
          ...weeks.map((week) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: week.map((d) {
              final isToday  = d == '14';
              final hasEvent = d == '15' || d == '18' || d == '19';
              return Expanded(
                child: Container(
                  height: 13,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? const BoxDecoration(color: _kAccent, shape: BoxShape.circle)
                      : null,
                  child: d == ' ' ? null : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d, style: TextStyle(
                        fontSize: 5, fontWeight: FontWeight.w600,
                        color: isToday ? Colors.white : hasEvent ? _kAccent : ink,
                      )),
                      if (hasEvent) Container(
                        width: 3, height: 3, margin: const EdgeInsets.only(top: 1),
                        decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
          )),
          const SizedBox(height: 7),
          // ── Mini event rows ────────────────────────────────────────────
          _MiniEvent(surface: surface, color: const Color(0xFF4FA870), label: 'Dinner & drinks', ink: ink),
          const SizedBox(height: 3),
          _MiniEvent(surface: surface, color: const Color(0xFF4A90E2), label: 'Weekend hike', ink: ink),
        ],
      ),
    );
  }
}

class _MiniEvent extends StatelessWidget {
  const _MiniEvent({required this.surface, required this.color, required this.label, required this.ink});
  final Color surface, color, ink;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(5)),
      child: Row(children: [
        Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 6, fontWeight: FontWeight.w600, color: ink)),
      ]),
    );
  }
}

// S9 — Checklist
class _LeftChecklist extends StatelessWidget {
  static const _items = [
    ('✅', 'Account created'),
    ('📅', 'Google Calendar synced'),
    ('🔔', 'Notifications on'),
    ('🎨', 'Profile personalised'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items.asMap().entries.map((e) {
        final item = e.value;
        return Padding(
          padding: EdgeInsets.only(bottom: e.key < _items.length - 1 ? 10 : 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF), width: 1),
            ),
            child: Row(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.$2,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kPanelText,
                      )),
                ),
                const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared right-panel widgets ────────────────────────────────────────────────

class _WebProgDots extends StatelessWidget {
  const _WebProgDots({required this.step, required this.total});
  final int step;  // 0-based current
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: filled ? 22.0 : 4.0,
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

class _WebScreenTitle extends StatelessWidget {
  const _WebScreenTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 32, fontWeight: FontWeight.w800,
          color: _kText, letterSpacing: -1, height: 1.15,
        ));
  }
}

class _WebField extends StatelessWidget {
  const _WebField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.onChanged,
    this.suffix,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, size: 16, color: _kText2.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _kText),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.plusJakartaSans(fontSize: 15, color: _kText2),
                border: InputBorder.none,
              ),
            ),
          ),
          if (suffix != null) ...[suffix!, const SizedBox(width: 12)],
        ],
      ),
    );
  }
}

class _WebStrengthMeter extends StatelessWidget {
  const _WebStrengthMeter({required this.strength});
  final int strength;

  static const _labels = ['', 'Too short', 'Good', 'Strong'];
  static const _colors = [
    Colors.transparent, Color(0xFFEF5350), Color(0xFFF5A623), Color(0xFF4FA870),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[strength];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) => Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < strength ? color : _kBorder,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          )),
        ),
        const SizedBox(height: 5),
        Text(_labels[strength],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: color,
            )),
      ],
    );
  }
}

class _WebAuthBtn extends StatelessWidget {
  const _WebAuthBtn({
    required this.label, required this.bg, required this.textColor,
    required this.border, required this.leading, required this.onTap,
  });
  final String label;
  final Color bg, textColor, border;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading, const SizedBox(width: 10),
            Text(label, style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w700, color: textColor,
            )),
          ],
        ),
      ),
    );
  }
}

class _WebPrimaryBtn extends StatelessWidget {
  const _WebPrimaryBtn({required this.label, required this.onTap, this.loading = false});
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null ? _kSurf2 : _kText,
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: GoogleFonts.plusJakartaSans(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kBg,
              )),
      ),
    );
  }
}

class _WebAccentBtn extends StatelessWidget {
  const _WebAccentBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(
            color: _kAccent.withValues(alpha: 0.35),
            blurRadius: 24, offset: const Offset(0, 8),
          )],
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w700, color: _kText,
        )),
      ),
    );
  }
}

class _WebOutlineBtn extends StatelessWidget {
  const _WebOutlineBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w600, color: _kText2,
        )),
      ),
    );
  }
}

class _WebNotifRow extends StatelessWidget {
  const _WebNotifRow({
    required this.emoji, required this.title, required this.sub,
    required this.selected, required this.onTap,
    this.disabled = false,
  });
  final String emoji, title, sub;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: IgnorePointer(
          ignoring: disabled,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x20F5A623) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _kAccent : _kBorder, width: 1.5),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: selected ? const Color(0x35F5A623) : _kSurf,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kText,
                  )),
                  Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kText2)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: selected ? _kAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? _kAccent : _kBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
          ],
        ),
      ),
          ),
        ),
      ),
    );
  }
}

class _WebThemeRow extends StatelessWidget {
  const _WebThemeRow({
    required this.label, required this.sub,
    required this.left, required this.right,
    required this.selected, required this.onTap,
  });
  final String label, sub;
  final Color left, right;
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
          color: selected ? const Color(0x14F5A623) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _kAccent : _kBorder, width: 1.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52, height: 38,
                child: Row(children: [
                  Expanded(child: Container(color: left)),
                  Expanded(child: Container(color: right)),
                ]),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kText,
                  )),
                  Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kText2)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: selected ? _kAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: selected ? _kAccent : _kBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _WebCheckRow extends StatelessWidget {
  const _WebCheckRow(this.emoji, this.label);
  final String emoji, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600, color: _kText,
          ))),
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 20),
        ],
      ),
    );
  }
}

// ── Confetti ──────────────────────────────────────────────────────────────────

class _WebConfetti extends StatefulWidget {
  const _WebConfetti();

  @override
  State<_WebConfetti> createState() => _WebConfettiState();
}

class _WebConfettiState extends State<_WebConfetti> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _p = [
    _CP(0.1, Color(0xFFF5A623), true,  0.0,  1.6),
    _CP(0.2, Color(0xFFF06292), false, 0.2,  2.0),
    _CP(0.3, Color(0xFF4285F4), true,  0.4,  1.4),
    _CP(0.5, Color(0xFF4FA870), false, 0.6,  1.8),
    _CP(0.6, Color(0xFF9B59B6), true,  0.8,  2.2),
    _CP(0.7, Color(0xFFEF5350), false, 0.3,  1.5),
    _CP(0.8, Color(0xFFFBBC05), true,  1.0,  2.0),
    _CP(0.9, Color(0xFF66BB6A), false, 1.4,  1.8),
    _CP(0.15,Color(0xFFFF7043), true,  1.8,  1.6),
    _CP(0.4, Color(0xFFAB47BC), false, 0.9,  1.9),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
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
      builder: (_, __) => SizedBox(
        width: double.infinity, height: 80,
        child: Stack(
          children: _p.map((p) {
            final t = ((_ctrl.value - p.delay / 2.5).clamp(0.0, 1.0));
            final y = -30.0 + t * 110.0;
            final op = (1.0 - t).clamp(0.0, 1.0);
            return Positioned(
              left: MediaQuery.sizeOf(context).width * 0.5 * p.x,
              top: 5 + y,
              child: Opacity(
                opacity: op,
                child: Transform.rotate(
                  angle: t * 6.28,
                  child: Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: p.color,
                      shape: p.square ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: p.square ? BorderRadius.circular(2) : null,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CP {
  final double x, delay, dur;
  final Color color;
  final bool square;
  const _CP(this.x, this.color, this.square, this.delay, this.dur);
}

