import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A swappable "dummy" icon.
///
/// Tries to load `assets/images/<name>.png`. If that file does not exist yet,
/// it gracefully falls back to rendering [fallbackEmoji] as text — so the app
/// looks complete out of the box, and a designer can later drop a real PNG into
/// `assets/images/` (using the matching name) to replace it app-wide.
///
/// Prefer the named constructors on [AppImages] over building this directly,
/// so the file name + emoji fallback stay defined in one place.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.name,
    required this.fallbackEmoji,
    this.size = 24,
  });

  /// Base file name without extension, e.g. `dummy_calendar`.
  final String name;

  /// Emoji shown when the PNG is missing.
  final String fallbackEmoji;

  /// Rendered width/height (and emoji font size).
  final double size;

  @override
  Widget build(BuildContext context) {
    // On web, Image.asset fires an HTTP request for every missing PNG, which
    // floods the browser console with 404s. Since the dummy_*.png files are
    // optional design-time assets, jump straight to the emoji on web.
    if (kIsWeb) {
      return Text(fallbackEmoji, style: TextStyle(fontSize: size, height: 1.0));
    }
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        fallbackEmoji,
        style: TextStyle(fontSize: size, height: 1.0),
      ),
    );
  }
}

/// Central registry of every swappable dummy icon in the app.
///
/// Each method returns an [AppImage] with the file name + emoji fallback baked
/// in, so call sites only choose the size. To replace an icon with a real
/// picture, drop the matching `dummy_*.png` into `assets/images/`.
abstract final class AppImages {
  static AppImage wave({double size = 24}) =>
      AppImage(name: 'dummy_wave', fallbackEmoji: '👋', size: size);

  static AppImage calendar({double size = 24}) =>
      AppImage(name: 'dummy_calendar', fallbackEmoji: '📅', size: size);

  static AppImage people({double size = 24}) =>
      AppImage(name: 'dummy_people', fallbackEmoji: '👥', size: size);

  static AppImage star({double size = 24}) =>
      AppImage(name: 'dummy_star', fallbackEmoji: '⭐', size: size);

  static AppImage party({double size = 24}) =>
      AppImage(name: 'dummy_party', fallbackEmoji: '🎉', size: size);

  static AppImage sparkles({double size = 24}) =>
      AppImage(name: 'dummy_sparkles', fallbackEmoji: '✨', size: size);

  static AppImage sprout({double size = 24}) =>
      AppImage(name: 'dummy_sprout', fallbackEmoji: '🌱', size: size);

  static AppImage poll({double size = 24}) =>
      AppImage(name: 'dummy_poll', fallbackEmoji: '📊', size: size);

  static AppImage note({double size = 24}) =>
      AppImage(name: 'dummy_note', fallbackEmoji: '📝', size: size);

  static AppImage flag({double size = 24}) =>
      AppImage(name: 'dummy_flag', fallbackEmoji: '🏁', size: size);

  static AppImage envelope({double size = 24}) =>
      AppImage(name: 'dummy_envelope', fallbackEmoji: '✉️', size: size);

  static AppImage mailbox({double size = 24}) =>
      AppImage(name: 'dummy_mailbox', fallbackEmoji: '📬', size: size);

  static AppImage lock({double size = 24}) =>
      AppImage(name: 'dummy_lock', fallbackEmoji: '🔐', size: size);

  static AppImage bell({double size = 24}) =>
      AppImage(name: 'dummy_bell', fallbackEmoji: '🔔', size: size);

  static AppImage target({double size = 24}) =>
      AppImage(name: 'dummy_target', fallbackEmoji: '🎯', size: size);

  static AppImage globe({double size = 24}) =>
      AppImage(name: 'dummy_globe', fallbackEmoji: '🌐', size: size);

  static AppImage phone({double size = 24}) =>
      AppImage(name: 'dummy_phone', fallbackEmoji: '📱', size: size);

  static AppImage sad({double size = 24}) =>
      AppImage(name: 'dummy_sad', fallbackEmoji: '😕', size: size);

  static AppImage check({double size = 24}) =>
      AppImage(name: 'dummy_check', fallbackEmoji: '✅', size: size);

  static AppImage moon({double size = 24}) =>
      AppImage(name: 'dummy_moon', fallbackEmoji: '🌙', size: size);
}
