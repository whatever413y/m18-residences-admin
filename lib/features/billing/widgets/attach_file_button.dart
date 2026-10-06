import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// "Attach Receipt" / "Change Payment" button: picks a file, converts it for upload ([prepareReceipt]) and reports
/// it through [onChanged] (`null` when the picked file can't be used). Shows the picked file's name and size, the
/// conversion progress or an error; [current] (e.g. the bill's View button) when nothing is picked yet. With
/// [onRemove], a Remove button drops the picked file and reports that the bill's own file should go too.
///
/// Test ids: `bill-attach-<receipt|payment>` (the button), `bill-<receipt|payment>-file` (the picked file),
/// `bill-remove-<receipt|payment>`.
class AttachFileButton extends StatefulWidget {
  final BillFileKind kind;

  /// Whether the bill already has this file ("Change" instead of "Attach").
  final bool hasFile;

  final ValueChanged<PreparedReceipt?> onChanged;

  /// Called with `true` while a picked file is being converted, then `false`.
  final ValueChanged<bool>? onPreparing;

  final Widget? current;

  /// Called when Remove is pressed; without it there is no Remove button.
  final VoidCallback? onRemove;

  const AttachFileButton({
    super.key,
    required this.kind,
    required this.hasFile,
    required this.onChanged,
    this.onPreparing,
    this.current,
    this.onRemove,
  });

  @override
  State<AttachFileButton> createState() => _AttachFileButtonState();
}

class _AttachFileButtonState extends State<AttachFileButton> {
  PreparedReceipt? _picked;
  bool _preparing = false;
  String? _error;

  /// Remove was pressed (and nothing picked since).
  bool _removed = false;

  void _remove() {
    setState(() {
      _picked = null;
      _error = null;
      _removed = true;
    });
    widget.onChanged(null);
    widget.onRemove!();
  }

  String get _title => '${widget.kind.subject[0].toUpperCase()}${widget.kind.subject.substring(1)}';

  void _setPreparing(bool preparing) {
    setState(() => _preparing = preparing);
    widget.onPreparing?.call(preparing);
  }

  Future<void> _pick() async {
    final ({String name, Uint8List bytes})? file;
    try {
      file = await pickFile(receiptExtensions);
    } catch (e) {
      setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    // Cancelling the picker keeps the file picked before (if any).
    if (file == null || !mounted) return;

    _error = null;
    _setPreparing(true);
    PreparedReceipt? prepared;
    try {
      prepared = await prepareReceipt(file.name, file.bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e is ReceiptException ? e.message : 'Could not read the file: $e');
    }
    if (!mounted) return;
    setState(() {
      _picked = prepared;
      if (prepared != null) _removed = false;
    });
    _setPreparing(false);
    widget.onChanged(prepared);
  }

  static String _size(int bytes) => bytes >= 1024 * 1024 ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

  static String _label(PreparedReceipt file) => file.wasConverted
      ? '${file.filename} · ${_size(file.bytes.length)} (was ${_size(file.originalSize)})'
      : '${file.filename} · ${_size(file.bytes.length)}';

  @override
  Widget build(BuildContext context) {
    final subject = widget.kind.subject;
    final picked = _picked;
    final canRemove = widget.onRemove != null && !_preparing && (widget.hasFile || picked != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              identifier: 'bill-attach-$subject',
              child: ElevatedButton.icon(
                onPressed: _preparing ? null : _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(widget.hasFile || picked != null ? 'Change $_title' : 'Attach $_title'),
              ),
            ),
            if (canRemove)
              Semantics(
                container: true,
                identifier: 'bill-remove-$subject',
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade800, minimumSize: const Size(48, 48)),
                  onPressed: _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              ),
          ],
        ),
        if (_preparing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Preparing $subject...', style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          )
        else if (picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              container: true,
              identifier: 'bill-$subject-file',
              child: Text(_label(picked), style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          )
        else if (_removed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('The $subject is removed when you save (kept in the archive).', style: const TextStyle(fontStyle: FontStyle.italic)),
          )
        else if (widget.current != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: widget.current!),
      ],
    );
  }
}
