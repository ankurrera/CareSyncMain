import 'package:flutter/material.dart';

/// Consistent spacing values throughout the app
abstract class AppSpacing {
  // Base spacing unit (4px)
  static const double unit = 4.0;

  // Spacing scale
  static const double xs = 4.0; // 1 unit
  static const double sm = 8.0; // 2 units
  static const double md = 16.0; // 4 units
  static const double lg = 24.0; // 6 units
  static const double xl = 32.0; // 8 units
  static const double xxl = 48.0; // 12 units

  // Common padding
  static const EdgeInsets screenPadding = EdgeInsets.all(20.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 12.0,
  );

  // Border radius (dense controls: rounded rects)
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusCard = 20.0; // V2 Card Radius Standard
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Squircle radii (superellipse surfaces — read softer than the numeric value)
  static const double squircleSheet = 80.0; // bottom sheets / overlays
  static const double squircleCard = 52.0; // default card / popup menu
  static const double squircleGrouped = 36.0; // grouped / settings cards

  // Gap & layout rhythm
  static const double gapCard = 12.0; // between sibling cards (settings)
  static const double gapHome = 16.0; // between sibling cards (home)
  static const double gapSection = 36.0; // between sections
  static const double pageMargin = 24.0; // page horizontal margin
  static const double appBarHeight = 72.0; // LinearFadeAppBar height budget
  static const double iconButton = 44.0; // circular icon-button diameter
  static const double twoButtonGap = 16.0; // gap in a two-button dialog row
  static const double bottomClearanceFab = 100.0; // bottom pad above nav / FAB

  // Icon sizes
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
}
