import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Opens [bill]'s details (selectable text). The tenant and room are looked up in [tenants] and [rooms]; the room is
/// the bill's reading's, else the tenant's current one.
Future<void> showBillDetails(BuildContext context, Bill bill, {required Map<int, Tenant> tenants, required Map<int, Room> rooms}) {
  final tenant = tenants[bill.tenantId];
  final room = rooms[bill.reading?.roomId ?? tenant?.roomId];
  return showSelectableDialog(
    context: context,
    builder: (_) => BillingDetailsDialog(
      bill: bill,
      tenantName: tenant?.name ?? 'Unknown Tenant',
      roomName: room?.name ?? 'Unknown Room',
      consumption: bill.consumption.toString(),
      date: DateFormat('MMM d, yyyy').format(bill.createdAt),
    ),
  );
}

/// A bill's details: who and when, every charge down to the total, the status, and View buttons for the tenant's
/// payment and the receipt (attached, changed and removed in the Update Bill form).
class BillingDetailsDialog extends StatelessWidget {
  final Bill bill;
  final String tenantName;
  final String roomName;
  final String consumption;
  final String date;

  const BillingDetailsDialog({
    super.key,
    required this.bill,
    required this.tenantName,
    required this.roomName,
    required this.consumption,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.windowSize.isCompact;
    return Dialog(
      insetPadding: compact ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Billing Details', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(tenantName, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text('$roomName · $date', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(container: true, identifier: 'bill-details-status', child: BillStatusChip(bill.status)),
                ],
              ),
              const SizedBox(height: 20),
              _section(context, 'Charges'),
              _row(context, 'Consumption', '$consumption kWh'),
              _row(context, 'Electric Charges', formatPeso(bill.electricCharges)),
              _row(context, 'Room Charges', formatPeso(bill.roomCharges)),
              for (final charge in bill.additionalCharges.where((c) => c.amount >= 0))
                _row(context, charge.description.isNotEmpty ? charge.description : 'Additional charge', formatPeso(charge.amount)),
              for (final charge in bill.additionalCharges.where((c) => c.amount < 0))
                _row(context, '${charge.description.isNotEmpty ? charge.description : 'Discount'} (discount)', formatPeso(charge.amount)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
              _row(context, 'Total Amount', formatPeso(bill.totalAmount), emphasized: true, semanticsId: 'bill-details-total'),
              const SizedBox(height: 20),
              _section(context, 'Payment from tenant'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!bill.hasPayment)
                    Text('No payment uploaded', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  Semantics(
                    container: true,
                    identifier: 'bill-view-payment',
                    child: buildBillFile(context, BillFileKind.payment, tenantName, bill.paymentUrl),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _section(context, 'Receipt from owner'),
              if (bill.hasReceipt)
                Align(alignment: Alignment.centerLeft, child: buildBillFile(context, BillFileKind.receipt, tenantName, bill.receiptUrl))
              else
                Text(
                  'No receipt yet: attach one with Edit bill or in Verify',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool emphasized = false, String? semanticsId}) {
    final theme = Theme.of(context);
    final style = emphasized ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 16),
          Text(
            value,
            textAlign: TextAlign.right,
            style: style?.copyWith(fontFeatures: AppTheme.tabularFigures),
          ),
        ],
      ),
    );
    return semanticsId == null ? row : Semantics(container: true, identifier: semanticsId, child: row);
  }
}
