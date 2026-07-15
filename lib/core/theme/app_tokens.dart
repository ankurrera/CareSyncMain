import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

// Bundled font families (declared in pubspec) — no runtime fetch.
TextStyle _dmSans({
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

TextStyle _dmMono({
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  Color? color,
}) => TextStyle(
  fontFamily: 'DM Mono',
  fontSize: fontSize,
  fontWeight: fontWeight,
  letterSpacing: letterSpacing,
  color: color,
);

/// Design tokens that have no direct Material [ColorScheme] / [TextTheme] slot.
///
/// Carries the brightness-resolved neutrals, semantic colours, opacity and
/// squircle-radius constants, plus the named DM Sans / DM Mono text styles used
/// for chrome and "technical" (mono) copy. Registered on [ThemeData.extensions]
/// and read via `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.scaffold,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentOn,
    required this.error,
    required this.outline,
    required this.divider,
    required this.skeleton,
    required this.tint,
    required this.glassAlpha,
    required this.appBarTitle,
    required this.sheetTitle,
    required this.monoSectionHeader,
    required this.monoMeta,
    required this.monoMenuItem,
  });

  // Neutrals & text
  final Color scaffold;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;

  // Accent & semantics
  final Color accent;
  final Color accentOn;
  final Color error;

  // Hairlines / fills (already opacity-resolved)
  final Color outline; // secondary @ 0.3
  final Color divider; // secondary @ 0.2
  final Color skeleton;
  final Color tint; // accent @ 0.1 (light) / 0.2 (dark)
  final double glassAlpha; // frosted-overlay background opacity (0.85)

  // Named text styles
  final TextStyle appBarTitle;
  final TextStyle sheetTitle;
  final TextStyle monoSectionHeader;
  final TextStyle monoMeta;
  final TextStyle monoMenuItem;

  // Squircle radii (mirrors AppSpacing for convenience at call sites)
  double get radiusSheet => AppSpacing.squircleSheet;
  double get radiusCard => AppSpacing.squircleCard;
  double get radiusGrouped => AppSpacing.squircleGrouped;

  static final AppTokens light = AppTokens(
    scaffold: AppColors.scaffoldLight,
    card: AppColors.cardLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    accent: AppColors.accentColor,
    accentOn: AppColors.accentOn,
    error: AppColors.errorLightMode,
    outline: AppColors.textSecondaryLight.withValues(alpha: 0.3),
    divider: AppColors.textSecondaryLight.withValues(alpha: 0.2),
    skeleton: AppColors.skeletonLight,
    tint: AppColors.accentColor.withValues(alpha: 0.1),
    glassAlpha: 0.85,
    appBarTitle: _dmSans(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      color: AppColors.textPrimaryLight,
    ),
    sheetTitle: _dmSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryLight,
    ),
    monoSectionHeader: _dmMono(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: AppColors.accentColor,
    ),
    monoMeta: _dmMono(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryLight,
    ),
    monoMenuItem: _dmMono(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryLight,
    ),
  );

  static final AppTokens dark = AppTokens(
    scaffold: AppColors.scaffoldDark,
    card: AppColors.cardDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    accent: AppColors.accentColor,
    accentOn: AppColors.accentOn,
    error: AppColors.errorDarkMode,
    outline: AppColors.textSecondaryDark.withValues(alpha: 0.3),
    divider: AppColors.textSecondaryDark.withValues(alpha: 0.2),
    skeleton: AppColors.skeletonDark,
    tint: AppColors.accentColor.withValues(alpha: 0.2),
    glassAlpha: 0.85,
    appBarTitle: _dmSans(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      color: AppColors.textPrimaryDark,
    ),
    sheetTitle: _dmSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimaryDark,
    ),
    monoSectionHeader: _dmMono(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: AppColors.accentColor,
    ),
    monoMeta: _dmMono(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondaryDark,
    ),
    monoMenuItem: _dmMono(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimaryDark,
    ),
  );

  @override
  AppTokens copyWith({
    Color? scaffold,
    Color? card,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentOn,
    Color? error,
    Color? outline,
    Color? divider,
    Color? skeleton,
    Color? tint,
    double? glassAlpha,
    TextStyle? appBarTitle,
    TextStyle? sheetTitle,
    TextStyle? monoSectionHeader,
    TextStyle? monoMeta,
    TextStyle? monoMenuItem,
  }) {
    return AppTokens(
      scaffold: scaffold ?? this.scaffold,
      card: card ?? this.card,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentOn: accentOn ?? this.accentOn,
      error: error ?? this.error,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      skeleton: skeleton ?? this.skeleton,
      tint: tint ?? this.tint,
      glassAlpha: glassAlpha ?? this.glassAlpha,
      appBarTitle: appBarTitle ?? this.appBarTitle,
      sheetTitle: sheetTitle ?? this.sheetTitle,
      monoSectionHeader: monoSectionHeader ?? this.monoSectionHeader,
      monoMeta: monoMeta ?? this.monoMeta,
      monoMenuItem: monoMenuItem ?? this.monoMenuItem,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      scaffold: Color.lerp(scaffold, other.scaffold, t)!,
      card: Color.lerp(card, other.card, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      error: Color.lerp(error, other.error, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      glassAlpha: glassAlpha,
      appBarTitle: TextStyle.lerp(appBarTitle, other.appBarTitle, t)!,
      sheetTitle: TextStyle.lerp(sheetTitle, other.sheetTitle, t)!,
      monoSectionHeader:
          TextStyle.lerp(monoSectionHeader, other.monoSectionHeader, t)!,
      monoMeta: TextStyle.lerp(monoMeta, other.monoMeta, t)!,
      monoMenuItem: TextStyle.lerp(monoMenuItem, other.monoMenuItem, t)!,
    );
  }
}

/// `context.tokens` — resolves the [AppTokens] for the active theme.
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
