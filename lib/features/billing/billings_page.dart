import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_bloc.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_event.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_state.dart';
import 'package:m18_residences_admin/features/billing/widgets/billing_details_dialog.dart';
import 'package:m18_residences_admin/features/billing/widgets/billing_form_dialog.dart';
import 'package:m18_residences_admin/features/shell/admin_shell.dart';
import 'package:m18_residences_admin/utils/admin_app_bar.dart';
import 'package:m18_residences_admin/utils/confirmation_action.dart';
import 'package:m18_residences_admin/utils/responsive_table.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class BillingsPage extends StatefulWidget {
  const BillingsPage({super.key});

  @override
  BillingsPageState createState() => BillingsPageState();
}

/// The loaded data indexed by id, and the bills shown for the current filters and sort.
class _BillsView {
  final BillingLoaded state;
  final Object settings;
  final Map<int, Tenant> tenants;
  final Map<int, Room> rooms;
  final List<TableColumn<Bill>> columns;
  final List<Bill> bills;

  const _BillsView(this.state, this.settings, this.tenants, this.rooms, this.columns, this.bills);
}

class BillingsPageState extends State<BillingsPage> {
  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

  /// Index of the Date column in [_columns], the default sort (newest first).
  static const _dateColumn = 7;

  /// Table widths at which more columns join (below [_tableMin]: cards). Measured with the default text size: the
  /// first tier is about 840 px wide, the second about 1,080, the full table about 1,370.
  static const _tableMin = 860.0;
  static const _withCharges = 1100.0;
  static const _full = 1400.0;

  late final BillingBloc billingBloc = context.read<BillingBloc>();
  bool _showActiveOnly = true;

  int? _filterRoomId;
  int? _filterTenantId;
  int? _filterYear = DateTime.now().year;
  int? _filterMonth = DateTime.now().month;
  int _sortColumn = _dateColumn;
  bool _sortAscending = false;

  /// Recomputed only when the data, the filters or the sort change, not on every build.
  _BillsView? _view;

  late final ValueNotifier<BillFilter?> _shellFilter;

  @override
  void initState() {
    super.initState();
    // Search and the dashboard open this page filtered to a tenant or a room (all their bills, any date).
    _shellFilter = AdminShell.of(context).billFilter..addListener(_applyShellFilter);
  }

  @override
  void dispose() {
    _shellFilter.removeListener(_applyShellFilter);
    super.dispose();
  }

  void _applyShellFilter() {
    final filter = _shellFilter.value;
    if (filter == null) return;
    setState(() {
      _filterTenantId = filter.tenantId;
      _filterRoomId = filter.roomId;
      _filterYear = null;
      _filterMonth = null;
      _showActiveOnly = false;
    });
    _shellFilter.value = null;
  }

  /// The room a bill is for: its reading's, else the tenant's current room.
  static int? _roomIdOf(Bill bill, Map<int, Tenant> tenants) => bill.reading?.roomId ?? tenants[bill.tenantId]?.roomId;

  _BillsView _viewOf(BillingLoaded state) {
    final settings = (_showActiveOnly, _filterRoomId, _filterTenantId, _filterYear, _filterMonth, _sortColumn, _sortAscending);
    final cached = _view;
    if (cached != null && identical(cached.state, state) && cached.settings == settings) return cached;

    final tenants = {for (final t in state.tenants) t.id: t};
    final rooms = {for (final r in state.rooms) r.id: r};
    final columns = _columns(tenants, rooms);
    final shown = state.bills.where((bill) {
      final tenant = tenants[bill.tenantId];
      if (_showActiveOnly && !(tenant?.isActive ?? false)) return false;
      if (_filterRoomId != null && _roomIdOf(bill, tenants) != _filterRoomId) return false;
      if (_filterTenantId != null && bill.tenantId != _filterTenantId) return false;
      if (_filterYear != null && bill.createdAt.year != _filterYear) return false;
      if (_filterMonth != null && bill.createdAt.month != _filterMonth) return false;
      return true;
    }).toList();
    return _view = _BillsView(state, settings, tenants, rooms, columns, sortItems(shown, columns[_sortColumn], ascending: _sortAscending));
  }

  List<TableColumn<Bill>> _columns(Map<int, Tenant> tenants, Map<int, Room> rooms) {
    String tenantName(Bill bill) => tenants[bill.tenantId]?.name ?? '-';
    String roomName(Bill bill) => rooms[_roomIdOf(bill, tenants)]?.name ?? '-';
    int additionalTotal(Bill bill) => bill.additionalCharges.fold(0, (sum, charge) => sum + charge.amount);
    // "120 kWh · Sep": the consumption and the month it was used (the month before the bill's).
    String usage(Bill bill) => '${bill.consumption} kWh · ${DateFormat.MMM().format(usageMonth(bill.createdAt))}';

    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget electric(Bill bill, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_currency.format(bill.electricCharges)),
        Text(usage(bill), style: muted),
      ],
    );
    Widget file(Bill bill, BillFileKind kind, String? url) => (url?.isNotEmpty ?? false)
        ? buildBillFile(context, kind, tenants[bill.tenantId]?.name, url, iconOnly: true)
        // Keeps the other file's button in its place.
        : const SizedBox(width: 48);

    return [
      TableColumn(
        'Tenant',
        (bill) => Text(tenantName(bill)),
        // The room under the name: the table has no Room column.
        tableCell: (bill) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tenantName(bill)),
            Text(roomName(bill), style: muted),
          ],
        ),
        sortKey: (bill) => tenantName(bill).toLowerCase(),
      ),
      TableColumn(
        'Room Charges',
        (bill) => Text(_currency.format(bill.roomCharges)),
        sortKey: (bill) => bill.roomCharges,
        numeric: true,
        minWidth: _withCharges,
      ),
      TableColumn(
        'Electric Charges',
        // The consumption under the amount (no Consumption column); right-aligned in the table.
        (bill) => electric(bill, CrossAxisAlignment.start),
        tableCell: (bill) => electric(bill, CrossAxisAlignment.end),
        sortKey: (bill) => bill.electricCharges,
        numeric: true,
        minWidth: _withCharges,
      ),
      TableColumn('Additional Charges', _additionalCharges, sortKey: additionalTotal, minWidth: _full),
      TableColumn(
        'Total',
        (bill) => Semantics(container: true, identifier: 'bill-total-${tenantName(bill)}', child: Text(_currency.format(bill.totalAmount))),
        sortKey: (bill) => bill.totalAmount,
        numeric: true,
      ),
      TableColumn(
        'Status',
        (bill) => Semantics(container: true, identifier: 'bill-status-${tenantName(bill)}', child: BillStatusChip(bill.status)),
        sortKey: (bill) => bill.status.index,
      ),
      TableColumn(
        'Files',
        (bill) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [file(bill, BillFileKind.payment, bill.paymentUrl), file(bill, BillFileKind.receipt, bill.receiptUrl)],
        ),
        inCards: false,
      ),
      // Last: the month filter already narrows the table to a month.
      TableColumn('Date', (bill) => Text(_dateFormat.format(bill.createdAt)), sortKey: (bill) => bill.createdAt),
      // Cards only: the table has the Files column and the room under the tenant.
      TableColumn(
        'Payment',
        (bill) => bill.hasPayment ? buildBillFile(context, BillFileKind.payment, tenants[bill.tenantId]?.name, bill.paymentUrl) : const Text('-'),
        sortKey: (bill) => bill.hasPayment ? 1 : 0,
        minWidth: double.infinity,
      ),
      TableColumn(
        'Receipt',
        (bill) => bill.hasReceipt ? buildBillFile(context, BillFileKind.receipt, tenants[bill.tenantId]?.name, bill.receiptUrl) : const Text('-'),
        sortKey: (bill) => bill.hasReceipt ? 1 : 0,
        minWidth: double.infinity,
      ),
      TableColumn('Room', (bill) => Text(roomName(bill)), sortKey: (bill) => roomName(bill).toLowerCase(), minWidth: double.infinity),
    ];
  }

  /// Each additional charge as "₱amount — note", so an amount stays next to its note at any width.
  Widget _additionalCharges(Bill bill) {
    if (bill.additionalCharges.isEmpty) return const Text('-');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final charge in bill.additionalCharges)
            Text(
              '${_currency.format(charge.amount)} — ${charge.description.isNotEmpty ? charge.description : '-'}',
              style: TextStyle(color: charge.amount < 0 ? Theme.of(context).colorScheme.error : null),
            ),
        ],
      ),
    );
  }

  Future<void> _showBillingDialog(BillingLoaded state, {Bill? bill}) async {
    final result = await showAppModal<BillFormResult>(
      context,
      builder: (context) => BillingFormDialog(
        showActiveOnly: _showActiveOnly,
        bill: bill,
        selectedRoomId: _filterRoomId,
        selectedTenantId: _filterTenantId,
        rooms: state.rooms,
        tenants: state.tenants,
        readings: state.readings,
      ),
    );
    if (!mounted || result == null) return;

    // Replaced by the bloc's result (see the listener).
    AppToast.show(context, bill != null ? 'Updating bill...' : 'Creating bill...', type: ToastType.loading);
    billingBloc.add(
      bill != null
          ? UpdateBill(bill.id, result.request, receipt: result.receipt, payment: result.payment, removePayment: result.removePayment)
          : AddBill(result.request, receipt: result.receipt, payment: result.payment),
    );
  }

  Future<void> _deleteBill(int id) async {
    final completer = Completer<void>();
    billingBloc.add(DeleteBill(id, onComplete: completer));
    return completer.future;
  }

  void _showBillingDetailsDialog(Bill bill, _BillsView view) => showBillDetails(context, bill, tenants: view.tenants, rooms: view.rooms);

  /// Only data loads change what the page shows; action results are reported by the listener.
  static bool _shows(BillingState state) => state is BillingInitial || state is BillingLoading || state is BillingLoaded || state is BillingError;

  @override
  Widget build(BuildContext context) {
    // Results of creating, updating and deleting bills are reported by the shell.
    return Scaffold(
      appBar: AdminAppBar(
        title: 'Billing',
        onRefresh: () => billingBloc.add(LoadBills()),
        actions: [buildActiveToggleFilter(showActiveOnly: _showActiveOnly, onChanged: (value) => setState(() => _showActiveOnly = value))],
      ),
      body: BlocBuilder<BillingBloc, BillingState>(
        buildWhen: (_, state) => _shows(state),
        builder: (context, state) {
          if (state is BillingError) {
            return ErrorView(message: state.message, onRetry: () => billingBloc.add(LoadBills()));
          }
          if (state is! BillingLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(context, _viewOf(state));
        },
      ),
      floatingActionButton: BlocBuilder<BillingBloc, BillingState>(
        buildWhen: (_, state) => _shows(state),
        builder: (context, state) => FloatingActionButton.extended(
          // Disabled until the billing data has loaded.
          onPressed: state is BillingLoaded ? () => _showBillingDialog(state) : null,
          label: const Text('Generate New Bill'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _BillsView view) {
    final state = view.state;
    // As wide as the window allows (1,600 px on large screens): the full table needs about 1,400.
    return ResponsiveCenter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, context.windowSize.isCompact ? 0 : 16),
        child: Column(
          children: [
            buildFilterBar(
              context,
              room: buildRoomFilter(
                rooms: state.rooms,
                tenants: state.tenants,
                selectedRoomId: _filterRoomId,
                selectedTenantId: _filterTenantId,
                onFilterChanged: (roomId, tenantId) => setState(() {
                  _filterRoomId = roomId;
                  _filterTenantId = tenantId;
                }),
              ),
              tenant: buildTenantFilter(
                tenants: state.tenants,
                selectedRoomId: _filterRoomId,
                selectedTenantId: _filterTenantId,
                showActiveOnly: _showActiveOnly,
                allLabel: 'All Tenants',
                onFilterChanged: (tenantId, roomId) => setState(() {
                  _filterTenantId = tenantId;
                  _filterRoomId = roomId;
                }),
              ),
              year: buildYearFilter(
                dates: state.bills.map((bill) => bill.createdAt),
                selectedYear: _filterYear,
                onYearChanged: (year) => setState(() => _filterYear = year),
              ),
              month: buildMonthFilter(selectedMonth: _filterMonth, onMonthChanged: (month) => setState(() => _filterMonth = month)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  billingBloc.add(LoadBills());
                  await billingBloc.stream.firstWhere((s) => s is! BillingLoading);
                },
                child: view.bills.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          EmptyState(icon: Icons.receipt_long_outlined, title: 'No bills found', message: 'Try other filters, or generate a bill.'),
                        ],
                      )
                    : ResponsiveTable<Bill>(
                        items: view.bills,
                        columns: view.columns,
                        sortColumn: _sortColumn,
                        sortAscending: _sortAscending,
                        onSort: (column, ascending) => setState(() {
                          _sortColumn = column;
                          _sortAscending = ascending;
                        }),
                        // Narrower screens get cards; wider ones a table with more columns as they fit.
                        tableMinWidth: _tableMin,
                        columnSpacing: 20,
                        onTap: (bill) => _showBillingDetailsDialog(bill, view),
                        actions: (bill) => _actions(bill, view),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(Bill bill, _BillsView view) {
    final tenantName = view.tenants[bill.tenantId]?.name ?? '-';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'bill-edit-$tenantName',
          child: IconButton(
            tooltip: 'Edit bill',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showBillingDialog(view.state, bill: bill),
          ),
        ),
        IconButton(
          tooltip: 'Delete bill',
          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          onPressed: () => showConfirmationAction(
            context: context,
            title: "Delete $tenantName's ${DateFormat.yMMMM().format(bill.createdAt)} bill?",
            message: "This can't be undone. Its receipt and payment images are kept in the archive.",
            confirmLabel: 'Delete bill',
            onConfirmed: () => _deleteBill(bill.id),
          ),
        ),
      ],
    );
  }
}
