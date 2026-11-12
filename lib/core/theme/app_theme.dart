import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design system v2 "Sunlit Field Guide" (docs/design/DESIGN.md).
/// Widgets use these tokens, never raw hex values.
abstract final class JT {
  // Canvas & surfaces
  static const cream = Color(0xFFFFF6E3);
  static const creamDeep = Color(0xFFFBEBCB);
  static const surface = Color(0xFFFFFDF8);
  static const line = Color(0xFFEDE3CC);

  // Sun band (Sliq-style header) + doodles drawn on it
  static const sun = Color(0xFFF7C548);
  static const sunSoft = Color(0xFFFBDD84);
  static const doodle = Color(0xFFDDA52A);

  // The one CTA colour: forest green (replaces Sliq's orange), white labels.
  static const forest = Color(0xFF1E5A3A);
  static const forestPressed = Color(0xFF164530);
  static const forestBright = Color(0xFF2F7A50);
  static const leaf = Color(0xFF5FA36A);
  static const mint = Color(0xFFE4F2E2);
  static const mintDeep = Color(0xFFCDE6CA);

  // Text
  static const ink = Color(0xFF1C1B16);
  static const muted = Color(0xFF6D685B);
  static const faint = Color(0xFFA39C89);

  // Status (only for state, never decoration)
  static const terracotta = Color(0xFFE0573B);
  static const terracottaSoft = Color(0xFFFCE3DA);
  static const sky = Color(0xFF3F86C6);

  // Dark scenes (Now Playing, QR)
  static const dusk = Color(0xFF0F2A1E);
  static const duskSoft = Color(0xFF173A2A);

  // Category tints (always paired with an icon)
  static const sejarah = Color(0xFFB0683A);
  static const alam = Color(0xFF3E8A4F);
  static const rekreasi = Color(0xFF2B8A85);
  static const informasi = Color(0xFF1E5A3A);
  static const fasilitas = Color(0xFF5B6B7A);

  static Color category(String c) => switch (c) {
        'sejarah' => sejarah,
        'alam' => alam,
        'rekreasi' => rekreasi,
        'fasilitas' => fasilitas,
        _ => informasi,
      };

  static Color categorySoft(String c) => Color.lerp(category(c), cream, 0.82)!;

  // Shape
  static const rCard = 22.0;
  static const rSheet = 30.0;
  static const rChip = 999.0;
  static const gutter = 20.0;
}

/// Typography. Variable fonts: weight is set through the `wght` axis so it renders the same
/// on Android and web.
abstract final class JTText {
  static TextStyle _b(double size, double w,
          {double height = 1.1, double track = -0.02, Color color = JT.ink}) =>
      TextStyle(
        fontFamily: 'Bricolage',
        fontSize: size,
        height: height,
        letterSpacing: size * track,
        fontWeight: _fw(w),
        fontVariations: [
          FontVariation('wght', w),
          const FontVariation('opsz', 48)
        ],
        color: color,
      );

  static TextStyle _j(double size, double w,
          {double height = 1.45, double track = 0, Color color = JT.ink}) =>
      TextStyle(
        fontFamily: 'Jakarta',
        fontSize: size,
        height: height,
        letterSpacing: size * track,
        fontWeight: _fw(w),
        fontVariations: [FontVariation('wght', w)],
        color: color,
      );

  static FontWeight _fw(double w) =>
      FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];

  static final hero = _b(40, 760, height: 1.02, track: -0.035);
  static final display = _b(32, 740, height: 1.05, track: -0.03);
  static final h1 = _b(26, 720, height: 1.1);
  static final h2 = _b(21, 700, height: 1.15);
  static final h3 = _b(18, 680, height: 1.2, track: -0.01);
  static final title = _j(16, 680, height: 1.3);
  static final body = _j(16, 450, height: 1.55);
  static final bodySm = _j(14, 480, height: 1.45);
  static final label = _j(14, 640, height: 1.2);
  static final caption = _j(12.5, 560, height: 1.3, color: JT.muted);
  static final overline =
      _j(11.5, 700, height: 1.2, track: 0.08, color: JT.muted);
  static final button = _j(16, 680, height: 1.1);

  /// Numbers: tabular figures so counters don't wobble.
  static TextStyle number(double size,
          {Color color = JT.ink, double w = 720}) =>
      _b(size, w, height: 1.0, track: -0.02, color: color)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Legacy tokens kept so older widgets (map module T04) still compile; mapped onto v2.
abstract final class AppColors {
  static const mistCanvas = JT.cream;
  static const pureSurface = JT.surface;
  static const pineInk = JT.ink;
  static const mossGray = JT.muted;
  static const lichenLine = JT.line;
  static const canopyDeep = JT.forest;
  static const canopyNight = JT.dusk;
  static const sunlitAmber = JT.sun;
  static const sunlitAmberPressed = JT.doodle;
  static const trailGreen = JT.leaf;
  static const trailGreenText = JT.forest;
  static const clayRed = JT.terracotta;
  static const positionBlue = JT.sky;
  static const heritageStone = JT.sejarah;
  static const fern = JT.alam;
  static const springTeal = JT.rekreasi;
  static const slatePost = JT.fasilitas;
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: JT.forest,
      primary: JT.forest,
      onPrimary: Colors.white,
      secondary: JT.sun,
      onSecondary: JT.ink,
      surface: JT.surface,
      onSurface: JT.ink,
      error: JT.terracotta,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Jakarta',
      scaffoldBackgroundColor: JT.cream,
      dividerColor: JT.line,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      }),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: JTText.hero,
        headlineLarge: JTText.display,
        headlineMedium: JTText.h1,
        titleLarge: JTText.h2,
        titleMedium: JTText.title,
        bodyLarge: JTText.body,
        bodyMedium: JTText.bodySm,
        labelLarge: JTText.label,
        bodySmall: JTText.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: JT.ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: JT.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: JTText.button,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : JT.surface),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? JT.forest : JT.line),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: JT.forest,
        inactiveTrackColor: JT.mintDeep,
        thumbColor: JT.forest,
        overlayColor: Color(0x221E5A3A),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: JT.ink,
        contentTextStyle: JTText.label.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
