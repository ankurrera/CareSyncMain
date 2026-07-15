import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

/// Flat 44×44 circular icon button — card-fill, no elevation.
///
/// Gives an [iconsax]-style glyph tappable presence without a shadow. Pass
/// [selected] for the accent-tinted active state.
class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.selected = false,
    this.size = AppSpacing.iconButton,
    this.iconSize = 22,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn = Material(
      color: selected ? t.tint : t.card,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: selected ? t.accent : t.textPrimary,
          ),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

/// Accent-filled circular FAB carrying the one sanctioned shadow (accent-glow).
class CircularFab extends StatelessWidget {
  const CircularFab({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 60,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle),
      child: Material(
        color: AppColors.accentColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: AppColors.accentOn),
          ),
        ),
      ),
    );
  }
}
