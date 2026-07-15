import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'squircle_border.dart';

/// Frosted-glass squircle used by transient overlays only (sheets, popups,
/// the floating nav) — never in-page. Card colour at 85% over a 20σ blur.
class FrostedSquircle extends StatelessWidget {
  const FrostedSquircle({
    super.key,
    required this.child,
    this.radius = AppSpacing.squircleSheet,
    this.blur = 20,
    this.color,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = (color ?? t.card).withValues(alpha: t.glassAlpha);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: SquircleBorder(radius: radius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        // Transparent Material so sheet content (ListTile, InkWell, …) always
        // has a Material ancestor without altering the frosted appearance.
        child: Container(
          color: base,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}
