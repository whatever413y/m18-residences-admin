import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_bloc.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_event.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_state.dart';
import 'package:m18_residences_admin/features/billing/widgets/billing_details_dialog.dart';
import 'package:m18_residences_admin/features/shell/admin_shell.dart';
import 'package:m18_residences_admin/utils/admin_app_bar.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// Payments waiting for the owner: bills with a tenant's payment image and no receipt yet. Each card shows the
/// payment and attaches the receipt (the same upload as the Update Bill form), which makes the bill Paid.
class VerifyPage extends StatelessWidget {
  const VerifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final billingBloc = context.read<BillingBloc>();
    return Scaffold(
      appBar: AdminAppBar(title: 'Verify payments', onRefresh: () => billingBloc.add(LoadBills())),
      body: BlocBuilder<BillingBloc, BillingState>(
        buildWhen: (_, state) => state is BillingLoading || state is BillingLoaded || state is BillingError,
        builder: (context, state) {
          final data = state is BillingLoaded ? state : AdminShell.of(context).billing;
          if (state is BillingError && data == null) return ErrorView(message: state.message, onRetry: () => billingBloc.add(LoadBills()));
          if (data == null) return const Center(child: CircularProgressIndicator());

          final waiting = data.bills.where((b) => b.status == BillStatus.forVerification).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (waiting.isEmpty) {
            return EmptyState(
              icon: Icons.task_alt,
              title: 'All payments verified',
              message: 'Payments tenants upload show here until you attach a receipt.',
              action: OutlinedButton.icon(
                onPressed: () => billingBloc.add(LoadBills()),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            );
          }

          final tenants = {for (final t in data.tenants) t.id: t};
          final rooms = {for (final r in data.rooms) r.id: r};
          final compact = context.windowSize.isCompact;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: 20),
            child: ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSection(
                    title: '${waiting.length} ${waiting.length == 1 ? 'payment' : 'payments'} to verify',
                    subtitle: 'Check each payment, then attach your receipt to mark the bill Paid.',
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Two cards side by side from tablet width, one on phones.
                      final columns = constraints.maxWidth >= 720 ? 2 : 1;
                      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final bill in waiting)
                            SizedBox(
                              width: width,
                              child: _VerifyCard(key: ValueKey(bill.id), bill: bill, tenants: tenants, rooms: rooms),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerifyCard extends StatefulWidget {
  final Bill bill;
  final Map<int, Tenant> tenants;
  final Map<int, Room> rooms;

  const _VerifyCard({super.key, required this.bill, required this.tenants, required this.rooms});

  @override
  State<_VerifyCard> createState() => _VerifyCardState();
}

class _VerifyCardState extends State<_VerifyCard> {
  bool _busy = false;
  String? _error;

  /// Picks the receipt, converts it in the browser and saves it on the bill (unchanged charges).
  Future<void> _attachReceipt() async {
    final bill = widget.bill;
    final ({String name, Uint8List bytes})? file;
    try {
      file = await pickFile(receiptExtensions);
    } catch (e) {
      setState(() => _error = 'Could not open the file picker: $e');
      return;
    }
    if (file == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await prepareReceipt(file.name, file.bytes);
      if (!mounted) return;
      final request = BillRequest(
        tenantId: bill.tenantId,
        readingId: bill.readingId,
        roomCharges: bill.roomCharges,
        electricCharges: bill.electricCharges,
        additionalCharges: bill.additionalCharges,
      );
      AppToast.show(context, 'Attaching receipt...', type: ToastType.loading);
      context.read<BillingBloc>().add(UpdateBill(bill.id, request, receipt: receipt));
    } catch (e) {
      if (mounted) setState(() => _error = e is ReceiptException ? e.message : 'Could not read the file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = widget.bill;
    final tenant = widget.tenants[bill.tenantId];
    final room = widget.rooms[bill.reading?.roomId ?? tenant?.roomId];
    final name = tenant?.name ?? 'Unknown tenant';

    return Card(
      child: InkWell(
        onTap: () => showBillDetails(context, bill, tenants: widget.tenants, rooms: widget.rooms),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      name.isEmpty ? '?' : name[0],
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                        Text(
                          '${room?.name ?? 'No room'} · ${DateFormat.yMMMM().format(bill.createdAt)}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  MoneyText(bill.totalAmount, style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              const BillStatusChip(BillStatus.forVerification),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  buildBillFile(context, BillFileKind.payment, bill.id, tenant?.name, bill.paymentUrl),
                  FilledButton.icon(
                    onPressed: _busy ? null : _attachReceipt,
                    icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.task_alt),
                    label: const Text('Attach receipt'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
