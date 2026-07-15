import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'squircle_card.dart';

/// Curve-based expand/collapse card (no spring physics).
///
/// The chevron rotates 0→180° and the body reveals with `easeInOut`; the whole
/// card gives a slight `easeOutBack` scale nudge on toggle to echo the original
/// spring overshoot.
class CSAccordion extends StatefulWidget {
  const CSAccordion({
    super.key,
    required this.title,
    required this.child,
    this.leadingIcon,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final IconData? leadingIcon;
  final bool initiallyExpanded;

  @override
  State<CSAccordion> createState() => _CSAccordionState();
}

class _CSAccordionState extends State<CSAccordion> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (widget.leadingIcon != null) ...[
                    Icon(widget.leadingIcon, size: 20, color: t.textPrimary),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(widget.title, style: textTheme.titleMedium),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                _expanded
                    ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: DefaultTextStyle.merge(
                        style: textTheme.bodyMedium!.copyWith(
                          color: t.textSecondary,
                        ),
                        child: widget.child,
                      ),
                    )
                    : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
