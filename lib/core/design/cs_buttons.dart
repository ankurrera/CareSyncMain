import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

/// Accent-filled stadium primary button. Full-width by default.
class CSPrimaryButton extends StatelessWidget {
  const CSPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child =
        loading
            ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
            : (icon == null
                ? Text(label)
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ));
    final btn = FilledButton(
      onPressed: loading ? null : onPressed,
      child: child,
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Neutral stadium secondary/cancel button (secondary-text @ 0.1 fill).
class CSSecondaryButton extends StatelessWidget {
  const CSSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final btn = TextButton(onPressed: onPressed, child: Text(label));
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Destructive stadium button (error fill, white text).
class CSDestructiveButton extends StatelessWidget {
  const CSDestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: context.tokens.error,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// The recurring confirmation layout: neutral (left) + accent/destructive
/// (right), each [Expanded], 16px apart.
class CSTwoButtonRow extends StatelessWidget {
  const CSTwoButtonRow({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    this.onCancel,
    this.onConfirm,
    this.destructive = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CSSecondaryButton(label: cancelLabel, onPressed: onCancel),
        ),
        const SizedBox(width: AppSpacing.twoButtonGap),
        Expanded(
          child:
              destructive
                  ? CSDestructiveButton(
                    label: confirmLabel,
                    onPressed: onConfirm,
                  )
                  : CSPrimaryButton(label: confirmLabel, onPressed: onConfirm),
        ),
      ],
    );
  }
}
