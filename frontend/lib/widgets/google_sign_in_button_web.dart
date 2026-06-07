import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import '../theme/app_theme.dart';

const _kWebClientId =
    '583283682704-ru7t2guho8bd8p42gmi1u6c8ruq9mq3a.apps.googleusercontent.com';

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
  StreamSubscription<GoogleSignInUserData?>? _sub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
      // Initialize GIS with the web client ID so renderButton works.
      await plugin.initWithParams(SignInInitParameters(
        clientId: _kWebClientId,
        scopes: ['email', 'openid'],
      ));
      _sub = plugin.userDataEvents?.listen(_handleUserData);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  void _handleUserData(GoogleSignInUserData? data) {
    if (data == null || !mounted) return;
    final idToken = data.idToken;
    if (idToken != null) {
      widget.onSignedIn(idToken);
    } else {
      widget.onError?.call('No ID token returned from Google');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Placeholder that matches the button size while GIS initializes.
      return SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.appColors.line, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
            backgroundColor: context.appColors.surface,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                  color: context.appColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // GIS enforces a hard maximum of 400 px on the rendered button.
    // Use that same cap here so the button fills whatever is available
    // up to 400 px, matching the visual weight of the stub button.
    const double _kGisMaxWidth = 400;
    final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth < _kGisMaxWidth ? constraints.maxWidth : _kGisMaxWidth;
        return SizedBox(
          height: 56,
          width: width,
          child: plugin.renderButton(
            configuration: GSIButtonConfiguration(
              type: GSIButtonType.standard,
              theme: GSIButtonTheme.outline,
              size: GSIButtonSize.large,
              text: GSIButtonText.continueWith,
              shape: GSIButtonShape.pill,
              minimumWidth: width,
            ),
          ),
        );
      },
    );
  }
}
