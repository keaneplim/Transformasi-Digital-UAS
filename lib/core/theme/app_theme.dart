import 'package:flutter/material.dart';

/// Colour tokens from docs/design/DESIGN.md §2. Widgets use these, never raw hex values.
abstract final class AppColors {
  static const mistCanvas = Color(0xFFF3F5F0);
  static const pureSurface = Color(0xFFFFFFFF);
  static const pineInk = Color(0xFF15211B);
  static const mossGray = Color(0xFF5F6B64);
  static const lichenLine = Color(0xFFDCE3DA);
  static const canopyDeep = Color(0xFF1E4634);
  static const canopyNight = Color(0xFF0F1A15);
  static const sunlitAmber = Color(0xFFD99A2B);
  static const sunlitAmberPressed = Color(0xFFC4871F);

  /// Status indicator only. For TEXT use [trailGreenText] (PROGRESS #19: #3E8A5B is 4.21:1 on white).
  static const trailGreen = Color(0xFF3E8A5B);
  static const trailGreenText = Color(0xFF357A4F);
  static const clayRed = Color(0xFFB5482B);
  static const positionBlue = Color(0xFF2F6FB0);

  static const heritageStone = Color(0xFF8B6B47); // sejarah
  static const fern = Color(0xFF4F7D4B); // alam
  static const springTeal = Color(0xFF3B7C78); // rekreasi
  static const slatePost = Color(0xFF5A6670); // fasilitas
}

abstract final class AppTheme {
  // TODO(C): bundle Plus Jakarta Sans / Fraunces / JetBrains Mono as asset fonts.
  // Don't use google_fonts runtime fetching — the app must work offline (A01).
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.canopyDeep,
      primary: AppColors.canopyDeep,
      secondary: AppColors.sunlitAmber,
      onSecondary: AppColors.pineInk, // labels on amber are always Pine Ink
      surface: AppColors.pureSurface,
      onSurface: AppColors.pineInk,
      error: AppColors.clayRed,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.mistCanvas,
      dividerColor: AppColors.lichenLine,
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sunlitAmber,
          foregroundColor: AppColors.pineInk,
          minimumSize: const Size.fromHeight(56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
