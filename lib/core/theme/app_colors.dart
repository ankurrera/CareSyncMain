import 'package:flutter/material.dart';

/// Canonical raw palette for the flat design language — two neutrals + one
/// fixed accent. Consumed by [AppTheme] and `AppTokens`; screens/widgets never
/// reference these directly (they use `context.tokens` / the M3 [ColorScheme]).
abstract class AppColors {
  // Neutrals (scaffold = page background, card = raised surface)
  static const Color scaffoldLight = Color(0xFFF5F5F5);
  static const Color scaffoldDark = Color(
    0xFF000000,
  ); // true black, OLED-friendly
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1A1A1A);

  // Text (primary = high-contrast ink, secondary = de-emphasised)
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFF888888);
  static const Color textSecondaryDark = Color(0xFFDBD5D5); // warm off-white

  // Single fixed accent (CareSync orange) + its foreground
  static const Color accentColor = Color(0xFFFF5200);
  static const Color accentOn = Color(0xFFFFFFFF);

  // Semantic error (brightness-resolved)
  static const Color errorLightMode = Color(0xFFDC2626);
  static const Color errorDarkMode = Color(0xFFEF4444);

  // Skeleton / loading fills
  static const Color skeletonLight = Color(0xFFE0E0E0);
  static const Color skeletonDark = Color(0xFF2A2A2A);
}
