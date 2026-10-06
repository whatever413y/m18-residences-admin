import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:m18_residences_admin/features/billing/widgets/attach_file_button.dart';
import 'package:m18_residences_admin/utils/form_dialog.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class AdditionalChargeInput {
  int amount;
  String description;

  AdditionalChargeInput({this.amount = 0, this.description = ''});
}

/// What the bill form returns: the bill to send, the receipt and payment image picked for it (if any), and
/// whether the bill's payment image is to be removed. (A removed receipt is simply not in [request].)
class BillFormResult {
  final BillRequest request;
  final PreparedReceipt? receipt;
  final PreparedReceipt? payment;
  final bool removePayment;

  const BillFormResult(this.request, this.receipt, this.payment, {this.removePayment = false});
}

class BillingFormDialog extends StatefulWidget {
  final Bill? bill;
  final List<Room> rooms;
  final List<Tenant> tenants;
  final List<Reading> readings;
  final int? selectedRoomId;
  final int? selectedTenantId;
  final bool showActiveOnly;

  const BillingFormDialog({
    super.key,
    required this.bill,
    required this.rooms,
    required this.tenants,
    required this.readings,
    required this.showActiveOnly,
    required this.selectedRoomId,
    required this.selectedTenantId,
  });

  @override
  State<BillingFormDialog> createState() => _BillingFormDialogState();
}

class _BillingFormDialogState extends State<BillingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roomChargesController = TextEditingController();
  final _electricChargesController = TextEditingController();
  final _electricityRateController = TextEditingController(text: '17');

  List<AdditionalChargeInput> _additionalCharges = [];
  List<TextEditingController> _additionalChargeControllers = [];
  List<TextEditingController> _additionalDescControllers = [];

  int? _selectedRoomId;
  int? _selectedTenantId;
  int? _selectedReadingId;

  /// The picked receipt and payment image, converted for upload.
  PreparedReceipt? _receipt;
  PreparedReceipt? _payment;

  /// How many picked files are being converted; the form can't be saved meanwhile.
  int _preparing = 0;
  String? _receiptUrl;
  String? _paymentUrl;

  /// Remove was pressed for the bill's payment image (and no new one picked).
  bool _removePayment = false;

  /// Why the form can't be saved yet (shown above the buttons), e.g. a tenant without a reading.
  String? _formError;

  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;

    if (bill != null && bill.additionalCharges.isNotEmpty) {
      _additionalCharges = bill.additionalCharges.map((e) => AdditionalChargeInput(amount: e.amount, description: e.description)).toList();
    } else {
      _additionalCharges = [AdditionalChargeInput()];
    }

    _additionalChargeControllers = _additionalCharges.map((e) => TextEditingController(text: e.amount.toString())).toList();

    _additionalDescControllers = _additionalCharges.map((e) => TextEditingController(text: e.description)).toList();

    if (bill != null) {
      final tenant = widget.tenants.firstWhereOrNull((t) => t.id == bill.tenantId);
      _selectedTenantId = bill.tenantId;
      _selectedRoomId = tenant?.roomId;
      _selectedReadingId = bill.readingId;
      _roomChargesController.text = bill.roomCharges.toString();
      _electricChargesController.text = bill.electricCharges.toString();
      final reading = _getReadingForSelection(roomId: _selectedRoomId, tenantId: _selectedTenantId, readingId: bill.readingId);
      final impliedRate = _calculateElectricityRate(bill.electricCharges, reading);
      _electricityRateController.text = impliedRate.toString();
      _receiptUrl = bill.receiptUrl;
      _paymentUrl = bill.paymentUrl;
    } else {
      _electricityRateController.text = '17';
      _selectedRoomId = widget.selectedRoomId;
      _selectedTenantId = widget.selectedTenantId;
      final reading = _getLatestReading(_selectedRoomId, _selectedTenantId);
      _selectedReadingId = reading?.id;
      _updateCharges();
    }
  }

  @override
  void dispose() {
    _roomChargesController.dispose();
    _electricChargesController.dispose();
    _electricityRateController.dispose();

    for (final c in _additionalChargeControllers) {
      c.dispose();
    }
    for (final c in _additionalDescControllers) {
      c.dispose();
    }

    super.dispose();
  }

  Reading? _getLatestReading(int? roomId, int? tenantId) {
    if (roomId == null || tenantId == null) return null;

    final filteredReadings = widget.readings.where((r) => r.roomId == roomId && r.tenantId == tenantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filteredReadings.isNotEmpty ? filteredReadings.first : null;
  }

  Reading? _getReadingForSelection({int? roomId, int? tenantId, int? readingId}) {
    if (readingId != null) {
      for (final reading in widget.readings) {
        if (reading.id == readingId) {
          return reading;
        }
      }
    }

    return _getLatestReading(roomId, tenantId);
  }

  int _getConsumption(Reading? reading) {
    if (reading == null) return 0;

    final explicitConsumption = reading.consumption;
    if (explicitConsumption > 0) {
      return explicitConsumption;
    }

    final derivedConsumption = reading.currReading - reading.prevReading;
    return derivedConsumption > 0 ? derivedConsumption : 0;
  }

  int _calculateElectricityRate(int electricCharges, Reading? reading) {
    final consumption = _getConsumption(reading);

    if (electricCharges > 0 && consumption > 0) {
      return (electricCharges / consumption).round();
    }

    return 17;
  }

  void _updateCharges() {
    _formError = null;
    if (_selectedRoomId == null || _selectedTenantId == null) {
      _roomChargesController.clear();
      _electricChargesController.clear();
      return;
    }

    final reading = _getLatestReading(_selectedRoomId, _selectedTenantId);
    _selectedReadingId = reading?.id;

    final room = widget.rooms.firstWhere((r) => r.id == _selectedRoomId, orElse: () => Room(id: 0, name: '', rent: 0));

    final roomCharges = room.rent.toInt();
    final electricConsumption = reading?.consumption ?? 0;
    final electricityRate = int.tryParse(_electricityRateController.text) ?? 17;
    final electricCharges = electricConsumption * electricityRate;

    _roomChargesController.text = roomCharges.toString();
    _electricChargesController.text = electricCharges.toString();
  }

  void _submit() {
    if (_preparing > 0) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tenantId = _selectedTenantId!;
    final readingId = _selectedReadingId;
    if (readingId == null) {
      setState(() => _formError = 'This tenant has no reading in this room yet: add one under Electric Readings first.');
      return;
    }

    final additionalCharges = <AdditionalCharge>[];
    for (var i = 0; i < _additionalCharges.length; i++) {
      final amount = int.tryParse(_additionalChargeControllers[i].text.trim()) ?? 0;
      final description = _additionalDescControllers[i].text.trim();
      if (amount == 0 && description.isEmpty) continue;
      additionalCharges.add(AdditionalCharge(amount: amount, description: description));
    }

    final request = BillRequest(
      tenantId: tenantId,
      readingId: readingId,
      roomCharges: int.tryParse(_roomChargesController.text) ?? 0,
      electricCharges: int.tryParse(_electricChargesController.text) ?? 0,
      additionalCharges: additionalCharges,
      receiptUrl: _receiptUrl,
    );
    Navigator.of(context).pop(BillFormResult(request, _receipt, _payment, removePayment: _removePayment && _payment == null));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: formDialogInset(context),
      title: Text(_isEditing ? 'Update Bill' : 'Generate Bill'),
      content: SizedBox(width: formDialogWidth(context), child: _buildContent()),
      actions: _buildActions(context),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoomDropdown(),
            const SizedBox(height: 16),
            _buildTenantDropdown(),
            const SizedBox(height: 16),
            _buildRoomChargesField(),
            const SizedBox(height: 16),
            _buildElectricChargesField(),
            const SizedBox(height: 16),
            _buildAdditionalChargesList(),
            const SizedBox(height: 16),
            _buildAttachButtons(),
            if (_formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }

  void _onPreparing(bool preparing) => setState(() => _preparing += preparing ? 1 : -1);

  /// The receipt (the bill is paid once it has one) and the tenant's optional payment image.
  Widget _buildAttachButtons() {
    final tenantName = widget.tenants.firstWhereOrNull((t) => t.id == _selectedTenantId)?.name;
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        AttachFileButton(
          kind: BillFileKind.receipt,
          hasFile: _receiptUrl?.isNotEmpty ?? false,
          onChanged: (file) => setState(() => _receipt = file),
          onPreparing: _onPreparing,
          current: buildBillFile(context, BillFileKind.receipt, tenantName, _receiptUrl),
          // Saving without a receipt URL clears it (the server archives the file).
          onRemove: () => setState(() => _receiptUrl = null),
        ),
        AttachFileButton(
          kind: BillFileKind.payment,
          hasFile: _paymentUrl?.isNotEmpty ?? false,
          onChanged: (file) => setState(() => _payment = file),
          onPreparing: _onPreparing,
          current: buildBillFile(context, BillFileKind.payment, tenantName, _paymentUrl),
          onRemove: () => setState(() {
            _removePayment = _paymentUrl?.isNotEmpty ?? false;
            _paymentUrl = null;
          }),
        ),
      ],
    );
  }

  /// An additional charge's amount; negative amounts are discounts.
  String? _validateAmount(int index, String? value) {
    final amount = int.tryParse(value?.trim() ?? '');
    final description = _additionalDescControllers[index].text.trim();
    if ((value?.trim().isNotEmpty ?? false) && amount == null) return 'Enter a whole number';
    if (description.isNotEmpty && (amount ?? 0) == 0) return 'Please fill in an amount';
    if ((amount ?? 0) != 0 && description.isEmpty) return 'Description is required';
    return null;
  }

  String? _validateDescription(int index, String? value) {
    final description = value?.trim() ?? '';
    final amount = int.tryParse(_additionalChargeControllers[index].text.trim()) ?? 0;
    if (description.isNotEmpty && amount == 0) return 'Please fill in an amount';
    if (amount != 0 && description.isEmpty) return 'Description is required';
    if (description.length > 200) return 'Description too long';
    return null;
  }

  void _removeCharge(int index) {
    setState(() {
      _additionalCharges.removeAt(index);
      _additionalChargeControllers[index].dispose();
      _additionalDescControllers[index].dispose();
      _additionalChargeControllers.removeAt(index);
      _additionalDescControllers.removeAt(index);
    });
  }

  Widget _peso() => Padding(
    padding: const EdgeInsets.all(12.0),
    child: Text(
      '₱',
      style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildAdditionalChargesList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side when the dialog (not the window) has room for both fields.
        final sideBySide = constraints.maxWidth >= 420;

        return Column(
          children: [
            ...List.generate(_additionalCharges.length, (index) {
              final amount = CustomTextFormField(
                controller: _additionalChargeControllers[index],
                labelText: 'Additional Charge',
                semanticsId: 'bill-charge-amount-$index',
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                prefixIcon: _peso(),
                validator: (value) => _validateAmount(index, value),
                onFieldSubmitted: (_) => _submit(),
              );
              final description = CustomTextFormField(
                controller: _additionalDescControllers[index],
                labelText: 'Description',
                semanticsId: 'bill-charge-description-$index',
                validator: (value) => _validateDescription(index, value),
                onFieldSubmitted: (_) => _submit(),
              );
              final remove = _additionalCharges.length > 1
                  ? IconButton(
                      tooltip: 'Remove charge',
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeCharge(index),
                    )
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: amount),
                          const SizedBox(width: 16),
                          Expanded(flex: 6, child: description),
                          if (remove != null) ...[const SizedBox(width: 8), remove],
                        ],
                      )
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [amount, const SizedBox(height: 12), description, ?remove]),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                container: true,
                identifier: 'bill-add-charge',
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _additionalCharges.add(AdditionalChargeInput());
                      _additionalChargeControllers.add(TextEditingController());
                      _additionalDescControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Additional Charge'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      Semantics(
        container: true,
        identifier: 'bill-save',
        child: ElevatedButton(
          // Disabled while a picked file is being converted.
          onPressed: _preparing > 0 ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(_isEditing ? 'Update Bill' : 'Generate Bill'),
        ),
      ),
    ];
  }

  Widget _buildRoomDropdown() {
    return buildRoomFilter(
      label: 'Room',
      rooms: widget.rooms,
      tenants: widget.tenants,
      selectedRoomId: _selectedRoomId,
      selectedTenantId: _selectedTenantId,
      onFilterChanged: (roomId, tenantId) {
        setState(() {
          _selectedRoomId = roomId;
          _selectedTenantId = tenantId;
          _updateCharges();
        });
      },
    );
  }

  Widget _buildTenantDropdown() {
    return buildTenantFilter(
      label: 'Select Tenant',
      semanticsId: 'bill-tenant',
      tenants: widget.tenants,
      selectedRoomId: _selectedRoomId,
      selectedTenantId: _selectedTenantId,
      showActiveOnly: widget.showActiveOnly,
      // Only a new bill takes the tenant's room; editing keeps the room chosen.
      autoSelectRoom: !_isEditing,
      onFilterChanged: (tenantId, roomId) {
        setState(() {
          _selectedTenantId = tenantId;
          _selectedRoomId = roomId;
          _updateCharges();
        });
      },
    );
  }

  Widget _buildRoomChargesField() {
    return CustomTextFormField(
      controller: _roomChargesController,
      labelText: 'Room Charges',
      semanticsId: 'bill-room-charges',
      enabled: false,
      prefixIcon: _peso(),
    );
  }

  Widget _buildElectricChargesField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: CustomTextFormField(controller: _electricChargesController, labelText: 'Electric Charges', enabled: false, prefixIcon: _peso()),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CustomTextFormField(
            controller: _electricityRateController,
            labelText: 'Rate',
            semanticsId: 'bill-rate',
            keyboardType: const TextInputType.numberWithOptions(signed: false),
            prefixIcon: _peso(),
            validator: (value) {
              final rate = int.tryParse(value ?? '') ?? 0;
              if (rate < 0) return 'Enter a valid number';
              return null;
            },
            onChanged: (_) => setState(_updateCharges),
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }
}
