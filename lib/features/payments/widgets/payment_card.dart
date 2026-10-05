import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m18_residences_admin/features/billing/receipt_converter.dart';
import 'package:m18_residences_admin/utils/pick_file.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Names the apps show for the payment methods' ids.
const paymentMethodLabels = {'bpi': 'BPI', 'gcash': 'GCash', 'maya': 'Maya'};

/// A payment method's QR code: a preview, its storage key, View (with Save) and Replace.
/// Replace picks an image, converts it to PNG in the browser and hands it to [onReplace].
class PaymentCard extends StatefulWidget {
  final PaymentImage image;
  final Future<SignedFile> Function() fetchFile;
  final void Function(Uint8List png) onReplace;

  const PaymentCard({super.key, required this.image, required this.fetchFile, required this.onReplace});

  @override
  State<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<PaymentCard> {
  Future<SignedFile>? _file;
  bool _converting = false;
  String? _error;

  String get _label => paymentMethodLabels[widget.image.name] ?? widget.image.name;

  @override
  void initState() {
    super.initState();
    _file = widget.image.exists ? widget.fetchFile() : null;
  }

  @override
  void didUpdateWidget(PaymentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reload (e.g. after a replace) brings new images: fetch a fresh link so the new picture shows.
    if (!identical(oldWidget.image, widget.image)) _file = widget.image.exists ? widget.fetchFile() : null;
  }

  Future<void> _replace() async {
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
      if (mounted) widget.onReplace(png);
    } catch (e) {
      if (mounted) setState(() => _error = e is ReceiptException ? e.message : 'Could not read the image: $e');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _view() => SignedImageDialog.show(
    context,
    fetchFile: widget.fetchFile,
    subject: '$_label QR code',
    fileName: widget.image.key,
    saveName: '${widget.image.name}-qr',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(widget.image.key, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(height: 200, child: Center(child: _preview())),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: widget.image.exists ? _view : null, icon: const Icon(Icons.zoom_in), label: const Text('View')),
                Semantics(
                  container: true,
                  identifier: 'payment-replace-${widget.image.name}',
                  child: FilledButton.icon(
                    onPressed: _converting ? null : _replace,
                    icon: _converting
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload),
                    label: Text(widget.image.exists ? 'Replace' : 'Upload'),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    final file = _file;
    if (file == null) return const Text('No QR code uploaded yet');
    return FutureBuilder<SignedFile>(
      future: file,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Text('Error loading the QR code: ${error is ApiException ? error.message : error}');
        }
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return InkWell(
          onTap: _view,
          child: Image.network(
            snapshot.data!.url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text('Failed to load image'),
          ),
        );
      },
    );
  }
}
