import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar.dart';

class AppTheme {
  // Surfaces
  static const bg          = Color(0xFFFFF8F0);
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFBF1E4);
  static const line        = Color(0xFFEFE4D2);

  // Ink
  static const ink      = Color(0xFF1F1B16);
  static const inkSoft  = Color(0xFF6B6357);
  static const inkMuted = Color(0xFFA39A8C);

  // Accents
  static const accent  = Color(0xFF7C5CFF);
  static const accent2 = Color(0xFFFFB347);

  // Danger
  static const danger = Color(0xFFE85535);

  // Legacy aliases so unchanged screens keep compiling
  static const primary      = ink;
  static const primaryLight = inkSoft;
  static const primaryDark  = ink;
  static const textPrimary  = ink;
  static const textSecondary = inkSoft;
  static const textMuted    = inkMuted;
  static const surfaceAlt   = surfaceSoft;
  static const border       = line;

  static ThemeData get light {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: ink,
        secondary: accent,
        error: danger,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ink,
      ),
      textTheme: base.copyWith(
        displayLarge:  base.displayLarge?.copyWith(color: ink, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        displayMedium: base.displayMedium?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineLarge: base.headlineLarge?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineMedium: base.headlineMedium?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineSmall: base.headlineSmall?.copyWith(color: ink, fontWeight: FontWeight.w600),
        titleLarge:  base.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w700),
        titleMedium: base.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
        titleSmall:  base.titleSmall?.copyWith(color: inkSoft, fontWeight: FontWeight.w500),
        bodyLarge:   base.bodyLarge?.copyWith(color: ink),
        bodyMedium:  base.bodyMedium?.copyWith(color: inkSoft),
        bodySmall:   base.bodySmall?.copyWith(color: inkMuted),
        labelLarge:  base.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: inkMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(color: inkMuted),
        prefixIconColor: inkMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
          shadowColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: ink, fontSize: 17, fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: line, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  // Keep the old getter name so app.dart still references something valid until updated
  static ThemeData get dark => light;
}

// ─── Hue palette ────────────────────────────────────────────────────────────

class CalHue {
  final String name;
  final Color bg;   // pastel background
  final Color ink;  // dark text on bg
  final Color dot;  // mid-tone dot / avatar
  final Color deep; // saturated shadow / accent
  const CalHue(this.name, this.bg, this.ink, this.dot, this.deep);
}

const List<CalHue> stickerHues = [
  CalHue('peach',  Color(0xFFFFD9C2), Color(0xFF7A3A1E), Color(0xFFFF8B5C), Color(0xFFFF6B3D)),
  CalHue('mint',   Color(0xFFC9EBD9), Color(0xFF1F5C42), Color(0xFF46B97F), Color(0xFF1F9D60)),
  CalHue('sky',    Color(0xFFCCE3FF), Color(0xFF1B3F7A), Color(0xFF4F8DEB), Color(0xFF2E6EE0)),
  CalHue('lilac',  Color(0xFFE2D6FF), Color(0xFF3F2A85), Color(0xFF9479F0), Color(0xFF7C5CFF)),
  CalHue('butter', Color(0xFFFFEDB0), Color(0xFF7A5A14), Color(0xFFE5B130), Color(0xFFC8951A)),
  CalHue('rose',   Color(0xFFFFD1DE), Color(0xFF7A2840), Color(0xFFEC6F92), Color(0xFFD9486F)),
  CalHue('sage',   Color(0xFFDBE7C7), Color(0xFF3F5524), Color(0xFF86A55B), Color(0xFF658543)),
  CalHue('coral',  Color(0xFFFFCFC2), Color(0xFF7A2A1A), Color(0xFFF37961), Color(0xFFE85535)),
];

// In-memory hue overrides set when a calendar is created/joined.
// Persisted to SharedPreferences so the choice survives restarts.
final Map<String, int> _calendarHueOverrides = {};

CalHue hueFor(CalendarModel c) {
  final override = _calendarHueOverrides[c.id];
  if (override != null) return stickerHues[override.clamp(0, stickerHues.length - 1)];
  return stickerHues[c.id.hashCode.abs() % stickerHues.length];
}

void setCalendarHue(String calendarId, int hueIndex) {
  _calendarHueOverrides[calendarId] = hueIndex;
}

/// Call once at startup to restore saved hue choices.
Future<void> loadCalendarHues() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith('cal_hue_'));
  for (final k in keys) {
    final id = k.substring('cal_hue_'.length);
    final idx = prefs.getInt(k);
    if (idx != null) _calendarHueOverrides[id] = idx;
  }
}

Future<void> persistCalendarHue(String calendarId, int hueIndex) async {
  setCalendarHue(calendarId, hueIndex);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('cal_hue_$calendarId', hueIndex);
}

// ─── StickerTile ────────────────────────────────────────────────────────────

class StickerTile extends StatelessWidget {
  const StickerTile({
    super.key,
    required this.hue,
    required this.child,
    this.size = 48,
    this.radius = 14,
  });

  final CalHue hue;
  final Widget child;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hue.bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: hue.deep.withOpacity(0.13),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
