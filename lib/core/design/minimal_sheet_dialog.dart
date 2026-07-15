import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'frosted_glass.dart';

/// Shows a floating, bottom-centred frosted sheet (not edge-attached) on the
/// root navigator. Replaces `showModalBottomSheet` in the flat design.
///
/// [builder] returns the sheet's inner content; it is automatically wrapped in
/// the drag handle + frosted squircle-80 card. Entry is curve-based (no springs):
/// 400 ms scale `easeOutBack` + fade + slide.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool showHandle = true,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(_AppSheetRoute<T>(builder: builder, showHandle: showHandle));
}

class _AppSheetRoute<T> extends PopupRoute<T> {
  _AppSheetRoute({required this.builder, required this.showHandle});

  final WidgetBuilder builder;
  final bool showHandle;

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.4);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _DragDismissible(
            child: FrostedSquircle(
              radius: AppSpacing.squircleSheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showHandle) const _DragHandle(),
                  Flexible(child: builder(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Container(
        width: 64,
        height: 5,
        decoration: BoxDecoration(
          color: context.tokens.textPrimary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Wraps sheet content with drag-to-dismiss: drag down > 100 px or fling
/// > 500 px/s pops; otherwise snaps back. Opacity dips to 0.7 across 300 px.
class _DragDismissible extends StatefulWidget {
  const _DragDismissible({required this.child});
  final Widget child;

  @override
  State<_DragDismissible> createState() => _DragDismissibleState();
}

class _DragDismissibleState extends State<_DragDismissible>
    with SingleTickerProviderStateMixin {
  double _offset = 0;

  void _onUpdate(DragUpdateDetails d) {
    setState(() => _offset = (_offset + d.delta.dy).clamp(0.0, 600.0));
  }

  void _onEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_offset > 100 || v > 500) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _offset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - _offset / 300).clamp(0.7, 1.0);
    return GestureDetector(
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 60),
        child: Transform.translate(
          offset: Offset(0, _offset),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Standard sheet content template: optional hero icon, title, body, then
/// action widgets. Use inside [showAppSheet]'s builder for consistency.
class AppSheetContent extends StatelessWidget {
  const AppSheetContent({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.children = const [],
  });

  final IconData? icon;
  final String title;
  final String? message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: t.accent),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Text(title, textAlign: TextAlign.center, style: t.sheetTitle),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: t.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (children.isNotEmpty) ...[const SizedBox(height: 24), ...children],
        ],
      ),
    );
  }
}
