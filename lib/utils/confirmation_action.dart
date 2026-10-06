import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

Future<bool> showConfirmationAction({
  required BuildContext context,
  required ScaffoldMessengerState messenger,
  required String confirmTitle,
  required String confirmContent,
  required Future<void> Function() onConfirmed,
}) async {
  final confirmed = await showSelectableDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(confirmTitle),
      content: Text(confirmContent),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  try {
    await onConfirmed();
    return true;
  } catch (e) {
    return false;
  }
}
