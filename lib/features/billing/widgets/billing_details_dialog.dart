import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/billing/widgets/attach_file_button.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class BillingDetailsDialog extends StatelessWidget {
  final Bill bill;
  final String tenantName;
  final String roomName;
  final String consumption;
  final String date;

  /// Called with a picked (and converted) payment image; the dialog closes.
  final ValueChanged<PreparedReceipt> onUploadPayment;

  const BillingDetailsDialog({
    super.key,
    required this.bill,
    required this.tenantName,
    required this.roomName,
    required this.consumption,
    required this.date,
    required this.onUploadPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 12,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(),
                const SizedBox(height: 16),
                _buildDivider(),
                const SizedBox(height: 16),
                _buildDetails(),
                const SizedBox(height: 24),
                _buildFiles(context),
                const SizedBox(height: 24),
                _buildCloseButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Status, the payment image (attach or change; Remove is in the Update Bill form) and the receipt.
  Widget _buildFiles(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Semantics(container: true, identifier: 'bill-details-status', child: BillStatusChip(bill.status)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Payment from tenant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!bill.hasPayment) const Text('No payment uploaded', style: TextStyle(color: Colors.grey)),
            Semantics(
              container: true,
              identifier: 'bill-view-payment',
              child: buildBillFile(context, BillFileKind.payment, tenantName, bill.paymentUrl),
            ),
            AttachFileButton(
              kind: BillFileKind.payment,
              hasFile: bill.hasPayment,
              onChanged: (payment) {
                if (payment == null) return;
                Navigator.of(context).pop();
                onUploadPayment(payment);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Receipt from owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (bill.hasReceipt)
          buildBillFile(context, BillFileKind.receipt, tenantName, bill.receiptUrl)
        else
          const Text('No receipt yet: attach one with Edit bill', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      'Billing Details',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade300, thickness: 1);
  }

  Widget _spacer() => const SizedBox(height: 12);

  Widget _buildDetails() {
    final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

    List<Widget> detailRows = [
      _buildDetailRow('Tenant', tenantName),
      _spacer(),
      _buildDetailRow('Room', roomName),
      _spacer(),
      _buildDetailRow('Consumption', '$consumption kWh'),
      _spacer(),
      _buildDetailRow('Electric Charges', currencyFormat.format(bill.electricCharges)),
      _spacer(),
      _buildDetailRow('Room Charges', currencyFormat.format(bill.roomCharges)),
    ];

    if (bill.additionalCharges.isNotEmpty) {
      buildChargesDetails(detailRows, bill.additionalCharges);
    }

    detailRows.addAll([
      _spacer(),
      _buildDivider(),
      _spacer(),
      _buildDetailRow('Total Amount', currencyFormat.format(bill.totalAmount), semanticsId: 'bill-details-total'),
      _spacer(),
      _buildDetailRow('Date', date),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: detailRows);
  }

  Widget _buildDetailRow(String label, String value, {String? semanticsId}) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
    return semanticsId == null ? row : Semantics(container: true, identifier: semanticsId, child: row);
  }

  void buildChargesDetails(List<Widget> detailRows, List<AdditionalCharge> charges) {
    final currencyFormat = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);
    final additionalCharges = charges.where((c) => c.amount >= 0).toList();
    final discounts = charges.where((c) => c.amount < 0).toList();

    if (additionalCharges.isNotEmpty) {
      detailRows.add(const SizedBox(height: 12));
      detailRows.add(const Text('Additional Charges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
      detailRows.add(const SizedBox(height: 8));

      for (final charge in additionalCharges) {
        detailRows.add(_buildChargeRow(charge.description, currencyFormat.format(charge.amount)));
      }
    }

    if (discounts.isNotEmpty) {
      detailRows.add(const SizedBox(height: 16));
      detailRows.add(const Text('Discounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)));
      detailRows.add(const SizedBox(height: 8));

      for (final charge in discounts) {
        detailRows.add(_buildChargeRow(charge.description, currencyFormat.format(charge.amount.abs())));
      }
    }
  }

  Widget _buildChargeRow(String description, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description.isNotEmpty ? description : '-',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
          Text(amount),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.blue.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}
