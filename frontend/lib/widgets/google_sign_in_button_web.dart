import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onSignedIn,
    this.onError,
    this.isLoading = false,
  });

  final void Function(String idToken) onSignedIn;
  final void Function(String error)? onError;
  // ignored on web — GIS button manages its own state
  final bool isLoading;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<GoogleSignInUserData?>? _sub;

  @override
  void initState() {
    super.initState();
    final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
    _sub = plugin.userDataEvents?.listen(_handleUserData);
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
    final plugin = GoogleSignInPlatform.instance as GoogleSignInPlugin;
    return SizedBox(
      height: 56,
      child: plugin.renderButton(
        configuration: GSIButtonConfiguration(
          type: GSIButtonType.standard,
          theme: GSIButtonTheme.outline,
          size: GSIButtonSize.large,
          text: GSIButtonText.continueWith,
          shape: GSIButtonShape.pill,
        ),
      ),
    );
  }
}
