import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'squircle_border.dart';

/// Flat (elevation-0) squircle surface — the base container of the design.
///
/// Fills with the card colour, clips content to a [SquircleBorder], and — when
/// [onTap] is set — hosts an [InkWell] whose ripple is clipped to the same
/// border. Separation from the page comes from colour + shape, never shadow.
class SquircleCard extends StatelessWidget {
  const SquircleCard({
    super.key,
    required this.child,
    this.radius = AppSpacing.squircleCard,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderSide = BorderSide.none,
    this.splashColor,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderSide borderSide;
  final Color? splashColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = SquircleBorder(radius: radius, side: borderSide);

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        customBorder: border,
        splashColor: splashColor,
        child: content,
      );
    }

    Widget card = Material(
      elevation: 0,
      color: color ?? context.tokens.card,
      shape: border,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }
    return card;
  }
}
