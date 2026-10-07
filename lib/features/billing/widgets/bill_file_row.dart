import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// One of a bill's files as a single row: an icon tile, its name ("Receipt" / "Payment from tenant") with its state
/// below, then its actions (View, Attach/Change, Remove) on the same line, or under the text when narrow.
class BillFileRow extends StatelessWidget {
  final BillFileKind kind;

  /// Whether the bill has (or will have, once saved) this file: tints the icon tile.
  final bool present;

  /// The state line, e.g. "Attached", "No receipt yet".
  final Widget status;

  final List<Widget> actions;

  const BillFileRow({super.key, required this.kind, required this.present, required this.status, this.actions = const []});

  static String title(BillFileKind kind) => switch (kind) {
    BillFileKind.receipt => 'Receipt',
    BillFileKind.payment => 'Payment from tenant',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tile = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: present ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Icon(kind.icon, size: 20, color: present ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title(kind), style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          child: status,
        ),
      ],
    );
    final buttons = Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: actions);
    return LayoutBuilder(
      builder: (context, constraints) {
        final head = Row(
          children: [
            tile,
            const SizedBox(width: 12),
            Expanded(child: text),
          ],
        );
        if (actions.isEmpty) return head;
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head,
              Padding(padding: const EdgeInsets.only(left: 52, top: 8), child: buttons),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: head),
            const SizedBox(width: 12),
            buttons,
          ],
        );
      },
    );
  }
}

/// The compact Attach/Change button of a [BillFileRow].
ButtonStyle _rowButtonStyle() =>
    OutlinedButton.styleFrom(minimumSize: const Size(48, 44), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10));

/// A bill file in the Update/Generate Bill form, as a [BillFileRow]: picks a file, converts it for upload
/// ([prepareReceipt]) and reports it through [onChanged] (`null` when nothing usable is picked). The row says what
/// will happen on save: the bill's file kept (with View), a new file (name and size), the file removed, or the
/// conversion progress or an error. Remove drops a picked file and reports through [onRemove] that the bill's own
/// file should go too.
///
/// Test ids: `bill-attach-<receipt|payment>` (Attach/Change), `bill-<receipt|payment>-file` (the picked file),
/// `bill-remove-<receipt|payment>`, `bill-view-<receipt|payment>`.
class BillFileField extends StatefulWidget {
  final BillFileKind kind;
  final String? tenantName;

  /// The bill's file (a file name), `null` when it has none or it was removed.
  final String? fileUrl;

  final ValueChanged<PreparedReceipt?> onChanged;

  /// Called with `true` while a picked file is being converted, then `false`.
  final ValueChanged<bool> onPreparing;

  final VoidCallback onRemove;

  const BillFileField({
    super.key,
    required this.kind,
    required this.tenantName,
    required this.fileUrl,
    required this.onChanged,
    required this.onPreparing,
    required this.onRemove,
  });

  @override
  State<BillFileField> createState() => _BillFileFieldState();
}

class _BillFileFieldState extends State<BillFileField> {
  PreparedReceipt? _picked;
  bool _preparing = false;
  String? _error;

  /// Remove was pressed (and nothing picked since).
  bool _removed = false;

  bool get _hasFile => widget.fileUrl?.isNotEmpty ?? false;

  void _remove() {
    setState(() {
      _picked = null;
      _error = null;
      _removed = true;
    });
    widget.onChanged(null);
    widget.onRemove();
  }

  void _setPreparing(bool preparing) {
    setState(() => _preparing = preparing);
    widget.onPreparing(preparing);
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
      ? 'New: ${file.filename} · ${_size(file.bytes.length)} (was ${_size(file.originalSize)})'
      : 'New: ${file.filename} · ${_size(file.bytes.length)}';

  Widget _status(BuildContext context) {
    final subject = widget.kind.subject;
    final picked = _picked;
    if (_preparing) {
      return Row(
        children: [
          const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Flexible(child: Text('Preparing $subject...')),
        ],
      );
    }
    if (_error != null) return Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error));
    if (picked != null) {
      return Semantics(container: true, identifier: 'bill-$subject-file', child: Text(_label(picked)));
    }
    if (_removed) return const Text('Removed when you save (kept in the archive)');
    if (_hasFile) return const Text('Attached');
    return Text(widget.kind == BillFileKind.receipt ? 'No receipt yet' : 'No payment uploaded');
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.kind.subject;
    final picked = _picked;
    final showView = _hasFile && picked == null && !_removed && !_preparing;
    final canRemove = !_preparing && (_hasFile || picked != null);
    return BillFileRow(
      kind: widget.kind,
      present: (_hasFile && !_removed) || picked != null,
      status: _status(context),
      actions: [
        if (showView)
          Semantics(
            container: true,
            identifier: 'bill-view-$subject',
            child: buildBillFile(context, widget.kind, widget.tenantName, widget.fileUrl, label: 'View'),
          ),
        Semantics(
          container: true,
          identifier: 'bill-attach-$subject',
          child: OutlinedButton.icon(
            style: _rowButtonStyle(),
            onPressed: _preparing ? null : _pick,
            icon: const Icon(Icons.attach_file, size: 18),
            label: Text(_hasFile || picked != null ? 'Change' : 'Attach'),
          ),
        ),
        if (canRemove)
          Semantics(
            container: true,
            identifier: 'bill-remove-$subject',
            child: IconButton(
              tooltip: 'Remove $subject',
              icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
              onPressed: _remove,
            ),
          ),
      ],
    );
  }
}
