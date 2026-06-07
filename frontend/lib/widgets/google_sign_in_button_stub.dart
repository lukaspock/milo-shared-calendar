import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';

const _kWebClientId =
    '583283682704-ru7t2guho8bd8p42gmi1u6c8ruq9mq3a.apps.googleusercontent.com';
const _kMacOSClientId =
    '583283682704-ethnu73r7o8rblkvra89qsibo0tlq7pp.apps.googleusercontent.com';

final _gsi = GoogleSignIn(
  clientId:
      defaultTargetPlatform == TargetPlatform.macOS ? _kMacOSClientId : null,
  serverClientId: _kWebClientId,
  scopes: ['email', 'openid'],
);

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onSignedIn,
    this.onError,
    this.isLoading = false,
  });

  final void Function(String idToken) onSignedIn;
  final void Function(String error)? onError;
  final bool isLoading;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _signing = false;

  Future<void> _handleTap() async {
    if (_signing || widget.isLoading) return;
    setState(() => _signing = true);
    try {
      final user = await _gsi.signIn();
      if (user == null) return; // cancelled
      final auth = await user.authentication;
      final idToken = auth.idToken;
      if (idToken != null) {
        widget.onSignedIn(idToken);
      } else {
        widget.onError?.call('No ID token returned from Google');
      }
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('cancelled') && !msg.contains('user_cancelled')) {
        widget.onError?.call(msg);
      }
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.isLoading || _signing;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: loading ? null : _handleTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.appColors.line, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28)),
          backgroundColor: context.appColors.surface,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appColors.inkMuted,
                ),
              )
            else ...[
              Text(
                'G',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
                    ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Continue with Google',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
