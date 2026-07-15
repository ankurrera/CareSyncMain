import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_tokens.dart';

/// Flat, high-contrast, elevation-0 theme. Two neutrals + one fixed accent.
class AppTheme {
  AppTheme._();

  // Bundled font families (declared in pubspec) — no runtime fetch.
  static TextStyle _dmSans({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
  }) => TextStyle(
    fontFamily: 'DM Sans',
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
  );

  // ───────────────────────── Type scale (DM Sans) ──────────────────────────
  static TextTheme _appTextTheme(Color color) {
    TextStyle s(double size, FontWeight weight, double spacing) => _dmSans(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
    );
    return TextTheme(
      displayLarge: s(57, FontWeight.w900, -0.25),
      displayMedium: s(45, FontWeight.w900, 0),
      displaySmall: s(36, FontWeight.w900, 0),
      headlineLarge: s(32, FontWeight.w700, 0),
      headlineMedium: s(28, FontWeight.w700, 0),
      headlineSmall: s(24, FontWeight.w700, 0),
      titleLarge: s(22, FontWeight.w600, 0),
      titleMedium: s(16, FontWeight.w600, 0.15),
      titleSmall: s(14, FontWeight.w600, 0.1),
      bodyLarge: s(16, FontWeight.w400, 0.5),
      bodyMedium: s(14, FontWeight.w400, 0.25),
      bodySmall: s(12, FontWeight.w400, 0.4),
      labelLarge: s(14, FontWeight.w500, 0.1),
      labelMedium: s(12, FontWeight.w500, 0.5),
      labelSmall: s(11, FontWeight.w500, 0.5),
    );
  }

  // ───────────────────────── Shared component themes ───────────────────────
  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
    required Color error,
    required AppTokens tokens,
    required SystemUiOverlayStyle overlay,
  }) {
    final outline = textSecondary.withValues(alpha: 0.3);
    final divider = textSecondary.withValues(alpha: 0.2);
    final textButtonFill = textSecondary.withValues(alpha: 0.1);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accentColor,
      onPrimary: AppColors.accentOn,
      secondary: AppColors.accentColor,
      onSecondary: AppColors.accentOn,
      primaryContainer: AppColors.accentColor,
      onPrimaryContainer: AppColors.accentOn,
      surface: card,
      onSurface: textPrimary,
      surfaceContainerLowest: scaffold,
      surfaceContainerLow: scaffold,
      surfaceContainer: card,
      surfaceContainerHigh: card,
      surfaceContainerHighest: card,
      onSurfaceVariant: textSecondary,
      outline: outline,
      outlineVariant: divider,
      error: error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: colorScheme,
      textTheme: _appTextTheme(textPrimary),
      iconTheme: IconThemeData(color: textPrimary),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: _dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: textPrimary,
        ),
        systemOverlayStyle: overlay,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          borderSide: BorderSide.none,
        ),
        hintStyle: _dmSans(color: textSecondary),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.accentColor,
          foregroundColor: AppColors.accentOn,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: _dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: textButtonFill,
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: _dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Legacy ElevatedButton call sites render on-brand until migrated.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.accentColor,
          foregroundColor: AppColors.accentOn,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: _dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: BorderSide(color: outline),
          shape: const StadiumBorder(),
          textStyle: _dmSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? AppColors.accentColor : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected)
                  ? AppColors.accentColor.withValues(alpha: 0.5)
                  : null,
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),

      extensions: [tokens],
    );
  }

  static ThemeData get lightTheme => _build(
    brightness: Brightness.light,
    scaffold: AppColors.scaffoldLight,
    card: AppColors.cardLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    error: AppColors.errorLightMode,
    tokens: AppTokens.light,
    overlay: SystemUiOverlayStyle.dark,
  );

  static ThemeData get darkTheme => _build(
    brightness: Brightness.dark,
    scaffold: AppColors.scaffoldDark,
    card: AppColors.cardDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    error: AppColors.errorDarkMode,
    tokens: AppTokens.dark,
    overlay: SystemUiOverlayStyle.light,
  );
}
