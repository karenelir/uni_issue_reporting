import 'package:flutter/material.dart';

import '../data/exceptions.dart';

/// Shows a short message at the bottom of the screen so every action gets
/// visible feedback. An optional [actionLabel] lets the user undo.
void showMessage(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: Duration(seconds: actionLabel != null ? 5 : 3),
    action: actionLabel != null && onAction != null
        ? SnackBarAction(label: actionLabel, onPressed: onAction)
        : null,
  ));
}

/// Turns any error into a plain-language message (NFR4, NFR7).
String describeError(Object error) {
  if (error is CampusFixException) return error.message;
  return 'Something went wrong. Please try again.';
}

/// Asks for confirmation before a drastic or irreversible action.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 16)),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
