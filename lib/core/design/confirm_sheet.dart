import 'package:flutter/material.dart';

import 'cs_buttons.dart';
import 'minimal_sheet_dialog.dart';

/// Confirmation dialog in the flat language — a floating sheet with a
/// neutral/accent (or destructive) two-button row. Returns `true` on confirm,
/// `false` on cancel or dismiss. Replaces inline `showDialog(AlertDialog(...))`.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  IconData? icon,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showAppSheet<bool>(
    context,
    builder:
        (ctx) => AppSheetContent(
          icon: icon,
          title: title,
          message: message,
          children: [
            CSTwoButtonRow(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              destructive: destructive,
              onCancel: () => Navigator.of(ctx).pop(false),
              onConfirm: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
  );
  return result ?? false;
}

/// Single-button informational sheet. Replaces inline alert `showDialog`s.
Future<void> showAlertSheet(
  BuildContext context, {
  required String title,
  String? message,
  IconData? icon,
  String buttonLabel = 'OK',
}) {
  return showAppSheet<void>(
    context,
    builder:
        (ctx) => AppSheetContent(
          icon: icon,
          title: title,
          message: message,
          children: [
            CSPrimaryButton(
              label: buttonLabel,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
  );
}
