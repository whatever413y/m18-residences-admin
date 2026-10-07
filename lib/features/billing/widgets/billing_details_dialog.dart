import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/billing/widgets/bill_file_row.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Opens [bill]'s details (selectable text). The tenant and room are looked up in [tenants] and [rooms]; the room is
/// the bill's reading's, else the tenant's current one.
Future<void> showBillDetails(BuildContext context, Bill bill, {required Map<int, Tenant> tenants, required Map<int, Room> rooms}) {
  final tenant = tenants[bill.tenantId];
  final room = rooms[bill.reading?.roomId ?? tenant?.roomId];
  return showAppModal(
    context,
    builder: (_) => BillingDetailsDialog(
      bill: bill,
      tenantName: tenant?.name ?? 'Unknown Tenant',
      roomName: room?.name ?? 'Unknown Room',
      consumption: bill.consumption.toString(),
      date: DateFormat('MMM d, yyyy').format(bill.createdAt),
    ),
  );
}

/// A bill's details: who and when, every charge down to the total, the status, and the tenant's payment and the
/// receipt as rows with View (attached, changed and removed in the Update Bill form).
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
    return AppModal(
      leading: AppModal.icon(context, Icons.receipt_long_outlined),
      overline: 'Billing Details',
      title: tenantName,
      subtitle: '$roomName · $date',
      trailing: Semantics(container: true, identifier: 'bill-details-status', child: BillStatusChip(bill.status)),
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppModalSection(
            label: 'Charges',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row(context, 'Consumption', '$consumption kWh'),
                _row(context, 'Electric Charges', formatPeso(bill.electricCharges)),
                _row(context, 'Room Charges', formatPeso(bill.roomCharges)),
                for (final charge in bill.additionalCharges.where((c) => c.amount >= 0))
                  _row(context, charge.description.isNotEmpty ? charge.description : 'Additional charge', formatPeso(charge.amount)),
                for (final charge in bill.additionalCharges.where((c) => c.amount < 0))
                  _row(context, '${charge.description.isNotEmpty ? charge.description : 'Discount'} (discount)', formatPeso(charge.amount)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _row(context, 'Total Amount', formatPeso(bill.totalAmount), emphasized: true, semanticsId: 'bill-details-total'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppModalSection(
            label: 'Files',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _file(context, BillFileKind.payment, bill.paymentUrl, missing: 'No payment uploaded'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                _file(context, BillFileKind.receipt, bill.receiptUrl, missing: 'No receipt yet: attach one with Edit bill or in Verify'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A file's row: "Attached" with View (test id `bill-view-<kind>`), or [missing].
  Widget _file(BuildContext context, BillFileKind kind, String? fileUrl, {required String missing}) {
    final present = fileUrl?.isNotEmpty ?? false;
    return BillFileRow(
      kind: kind,
      present: present,
      status: Text(present ? 'Attached' : missing),
      actions: [
        if (present)
          Semantics(
            container: true,
            identifier: 'bill-view-${kind.subject}',
            child: buildBillFile(context, kind, tenantName, fileUrl, label: 'View'),
          ),
      ],
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
