import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// A payment method: its name and account, a preview of its QR code, View (with Save), Upload/Replace and Remove
/// for the QR code, and Edit/Delete in its menu. Upload picks an image, converts it to PNG in the browser and hands
/// it to [onUpload]. Test ids: `payment-replace-<slug>`, `payment-menu-<slug>`, `payment-remove-qr-<slug>`.
class PaymentCard extends StatefulWidget {
  final PaymentMethod method;
  final Future<SignedFile> Function() fetchFile;
  final void Function(Uint8List png) onUpload;
  final VoidCallback onRemoveImage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PaymentCard({
    super.key,
    required this.method,
    required this.fetchFile,
    required this.onUpload,
    required this.onRemoveImage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<PaymentCard> {
  Future<SignedFile>? _file;
  bool _converting = false;
  String? _error;

  PaymentMethod get _method => widget.method;

  @override
  void initState() {
    super.initState();
    _file = _method.hasImage ? widget.fetchFile() : null;
  }

  @override
  void didUpdateWidget(PaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reload (e.g. after an upload) brings new methods: fetch a fresh link so the new picture shows.
    if (!identical(oldWidget.method, widget.method)) _file = _method.hasImage ? widget.fetchFile() : null;
  }

  Future<void> _upload() async {
    setState(() => _error = null);
    final ({String name, Uint8List bytes})? file;
    try {
      file = await pickFile(receiptExtensions.where((extension) => extension != 'pdf').toList());
    } catch (e) {
      setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _converting = true);
    try {
      final png = await prepareQrPng(file.bytes);
      if (mounted) widget.onUpload(png);
    } catch (e) {
      if (mounted) setState(() => _error = e is ReceiptException ? e.message : 'Could not read the image: $e');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _view() => SignedImageDialog.show(
    context,
    fetchFile: widget.fetchFile,
    subject: '${_method.name} QR code',
    fileName: '${_method.name} QR code',
    saveName: '${_method.slug}-qr',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slug = _method.slug;
    final account = [_method.accountName, _method.accountNumber].whereType<String>().join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppModal.icon(context, Icons.account_balance_wallet_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_method.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        account.isEmpty ? 'No account details' : account,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  identifier: 'payment-menu-$slug',
                  child: PopupMenuButton<VoidCallback>(
                    tooltip: 'More for ${_method.name}',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: widget.onEdit,
                        child: const ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit')),
                      ),
                      PopupMenuItem(
                        value: widget.onDelete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: scheme.error),
                          title: Text('Delete', style: TextStyle(color: scheme.error)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.softPanelColor(scheme),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Center(child: _preview(context)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(onPressed: _method.hasImage ? _view : null, icon: const Icon(Icons.zoom_in), label: const Text('View')),
                Semantics(
                  container: true,
                  identifier: 'payment-replace-$slug',
                  child: FilledButton.icon(
                    onPressed: _converting ? null : _upload,
                    icon: _converting
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload),
                    label: Text(_method.hasImage ? 'Replace' : 'Upload'),
                  ),
                ),
                if (_method.hasImage)
                  Semantics(
                    container: true,
                    identifier: 'payment-remove-qr-$slug',
                    child: IconButton(
                      tooltip: 'Remove the QR code',
                      icon: Icon(Icons.remove_circle_outline, color: scheme.error),
                      onPressed: widget.onRemoveImage,
                    ),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final file = _file;
    if (file == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('No QR code uploaded yet', style: muted),
        ],
      );
    }
    return FutureBuilder<SignedFile>(
      future: file,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Text('QR code not available: ${error is ApiException ? error.message : error}', style: muted, textAlign: TextAlign.center);
        }
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return InkWell(
          onTap: _view,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snapshot.data!.url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text('Failed to load image', style: muted),
            ),
          ),
        );
      },
    );
  }
}
