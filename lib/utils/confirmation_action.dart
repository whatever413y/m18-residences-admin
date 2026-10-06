import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Asks before a destructive action: [title] names what goes ("Delete ECHO's October 2026 bill?"), [message] says
/// what follows, and the red button says what it does ([confirmLabel], e.g. "Delete bill"). Cancel has the focus,
/// so Enter never deletes. Runs [onConfirmed] once confirmed; returns whether it ran without an error (its failure
/// is reported by the page, e.g. with a toast).
Future<bool> showConfirmationAction({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() onConfirmed,
}) async {
  final confirmed = await showAppModal<bool>(
    context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AppModal(
        leading: AppModal.icon(context, Icons.delete_outline, background: scheme.errorContainer, foreground: scheme.onErrorContainer),
        title: title,
        maxWidth: 440,
        actions: [
          OutlinedButton(autofocus: true, onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      );
    },
  );

  if (confirmed != true) return false;

  try {
    await onConfirmed();
    return true;
  } catch (e) {
    return false;
  }
}
