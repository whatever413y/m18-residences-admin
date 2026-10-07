import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// Knows whether a form differs from how it opened: [formSnapshot] lists the values that count as a change
/// (compared deeply), [markPristine] records them once the form is filled in (end of `initState`).
mixin DirtyTracking<T extends StatefulWidget> on State<T> {
  List<Object?>? _pristine;

  /// The form's current values that count as a change (trimmed text, selected ids, picked files...).
  List<Object?> get formSnapshot;

  void markPristine() => _pristine = formSnapshot;

  /// Whether any value differs from the recorded one.
  bool get isDirty => _pristine == null || !const DeepCollectionEquality().equals(_pristine, formSnapshot);
}

/// A form's Save button (test id [id]) that is disabled while [canSave] is false, with [disabledReason] as its
/// tooltip then. [listenable] (the form's text controllers) rebuilds it while typing, so [canSave] is re-read without
/// rebuilding the whole form.
class FormSaveButton extends StatelessWidget {
  final String id;
  final String label;
  final bool Function() canSave;
  final VoidCallback onPressed;
  final String disabledReason;
  final Listenable listenable;

  const FormSaveButton({
    super.key,
    required this.id,
    required this.label,
    required this.canSave,
    required this.onPressed,
    required this.disabledReason,
    required this.listenable,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final enabled = canSave();
        final button = FilledButton(onPressed: enabled ? onPressed : null, child: Text(label));
        return Semantics(
          container: true,
          identifier: id,
          child: enabled ? button : Tooltip(message: disabledReason, child: button),
        );
      },
    );
  }
}
