import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m18_residences_admin/utils/dirty_form.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// What the payment method form returns: the method to send and, for a new one, its QR image (a PNG) if picked.
class PaymentMethodFormResult {
  final PaymentMethodRequest request;
  final Uint8List? png;

  const PaymentMethodFormResult(this.request, this.png);
}

/// Adds or edits a payment method: its name, the account tenants pay to, and its place in the list; a new one can
/// get its QR code right away (an edited one changes it on its card). Test ids: `payment-method-name`,
/// `payment-method-account-name`, `payment-method-account-number`, `payment-method-position`,
/// `payment-method-attach-qr`, `payment-method-save`.
class PaymentMethodFormDialog extends StatefulWidget {
  final PaymentMethod? method;

  const PaymentMethodFormDialog({super.key, this.method});

  @override
  State<PaymentMethodFormDialog> createState() => _PaymentMethodFormDialogState();
}

class _PaymentMethodFormDialogState extends State<PaymentMethodFormDialog> with DirtyTracking {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.method?.name ?? '');
  late final _accountNameController = TextEditingController(text: widget.method?.accountName ?? '');
  late final _accountNumberController = TextEditingController(text: widget.method?.accountNumber ?? '');
  late final _positionController = TextEditingController(text: widget.method?.sortOrder.toString() ?? '');

  Uint8List? _png;
  bool _converting = false;
  String? _qrError;

  bool get _isEditing => widget.method != null;

  @override
  void initState() {
    super.initState();
    markPristine();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  List<Object?> get formSnapshot => [
    _nameController.text.trim(),
    _accountNameController.text.trim(),
    _accountNumberController.text.trim(),
    _positionController.text.trim(),
  ];

  /// A new method needs a name; an edit, a change. Never while the picked QR image is being converted.
  bool _canSave() => !_converting && (_isEditing ? isDirty : _nameController.text.trim().isNotEmpty);

  Future<void> _pickQr() async {
    setState(() => _qrError = null);
    final ({String name, Uint8List bytes})? file;
    try {
      file = await pickFile(receiptExtensions.where((extension) => extension != 'pdf').toList());
    } catch (e) {
      setState(() => _qrError = 'Could not open the file picker: $e');
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _converting = true);
    try {
      final png = await prepareQrPng(file.bytes);
      if (mounted) setState(() => _png = png);
    } catch (e) {
      if (mounted) setState(() => _qrError = e is ReceiptException ? e.message : 'Could not read the image: $e');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _submit() {
    if (!_canSave()) return;
    if (_formKey.currentState?.validate() != true) return;
    final position = _positionController.text.trim();
    final request = PaymentMethodRequest(
      name: _nameController.text.trim(),
      accountName: _accountNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      sortOrder: position.isEmpty ? null : int.parse(position),
    );
    Navigator.of(context).pop(PaymentMethodFormResult(request, _png));
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      leading: AppModal.icon(context, Icons.account_balance_wallet_outlined),
      title: _isEditing ? 'Edit Payment Method' : 'New Payment Method',
      subtitle: _isEditing ? widget.method!.name : 'A bank or e-wallet tenants can pay to',
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FormSaveButton(
          id: 'payment-method-save',
          label: _isEditing ? 'Save' : 'Add',
          canSave: _canSave,
          onPressed: _submit,
          disabledReason: _converting
              ? 'Wait until the QR code is ready'
              : _isEditing
              ? 'Nothing changed yet'
              : 'Enter a name',
          listenable: Listenable.merge([_nameController, _accountNameController, _accountNumberController, _positionController]),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppModalSection(
              label: 'Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextFormField(
                    controller: _nameController,
                    labelText: 'Name (e.g. GCash, BPI)',
                    semanticsId: 'payment-method-name',
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Enter a name';
                      if (name.length > 40) return 'At most 40 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextFormField(
                    controller: _accountNameController,
                    labelText: 'Account name (optional)',
                    semanticsId: 'payment-method-account-name',
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (value) => (value?.trim().length ?? 0) > 80 ? 'At most 80 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextFormField(
                    controller: _accountNumberController,
                    labelText: 'Account or mobile number (optional)',
                    semanticsId: 'payment-method-account-number',
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.numbers),
                    validator: (value) => (value?.trim().length ?? 0) > 40 ? 'At most 40 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextFormField(
                    controller: _positionController,
                    labelText: _isEditing ? 'Position in the list' : 'Position in the list (optional: last)',
                    semanticsId: 'payment-method-position',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    prefixIcon: const Icon(Icons.format_list_numbered),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final position = int.tryParse(text);
                      return position == null || position < 0 || position > 999 ? 'A number from 0 to 999' : null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            if (!_isEditing) ...[const SizedBox(height: 20), AppModalSection(label: 'QR code', child: _qrSection(context))],
          ],
        ),
      ),
    );
  }

  Widget _qrSection(BuildContext context) {
    final theme = Theme.of(context);
    final png = _png;
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.panelColor(theme.colorScheme),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: png == null ? Icon(Icons.qr_code_2, color: theme.colorScheme.onSurfaceVariant) : Image.memory(png, fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _qrError ?? (_converting ? 'Preparing the QR code...' : (png == null ? 'Optional: add it now or later' : 'Ready to upload')),
                style: theme.textTheme.bodySmall?.copyWith(color: _qrError != null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Semantics(
                container: true,
                identifier: 'payment-method-attach-qr',
                child: OutlinedButton.icon(
                  onPressed: _converting ? null : _pickQr,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: Text(png == null ? 'Choose image' : 'Change image'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
