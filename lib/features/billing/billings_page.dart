import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_bloc.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_event.dart';
import 'package:m18_residences_admin/features/billing/bloc/billing_state.dart';
import 'package:m18_residences_admin/features/billing/widgets/billing_details_dialog.dart';
import 'package:m18_residences_admin/features/billing/widgets/billing_form_dialog.dart';
import 'package:m18_residences_admin/utils/confirmation_action.dart';
import 'package:m18_residences_admin/utils/custom_snackbar.dart';
import 'package:m18_residences_admin/utils/responsive_table.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class BillingsPage extends StatefulWidget {
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
  static const _dateColumn = 6;

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

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(CheckAuthStatus());
    billingBloc.add(LoadBills());
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

    return [
      TableColumn('Tenant', (bill) => Text(tenantName(bill)), sortKey: (bill) => tenantName(bill).toLowerCase()),
      TableColumn('Consumption (kWh)', (bill) => Text('${bill.consumption}'), sortKey: (bill) => bill.consumption, numeric: true),
      TableColumn('Electric Charges', (bill) => Text(_currency.format(bill.electricCharges)), sortKey: (bill) => bill.electricCharges, numeric: true),
      TableColumn('Room Charges', (bill) => Text(_currency.format(bill.roomCharges)), sortKey: (bill) => bill.roomCharges, numeric: true),
      TableColumn('Additional Charges', _additionalCharges, sortKey: additionalTotal),
      TableColumn(
        'Total',
        (bill) => Semantics(container: true, identifier: 'bill-total-${tenantName(bill)}', child: Text(_currency.format(bill.totalAmount))),
        sortKey: (bill) => bill.totalAmount,
        numeric: true,
      ),
      TableColumn('Date', (bill) => Text(_dateFormat.format(bill.createdAt)), sortKey: (bill) => bill.createdAt),
      TableColumn(
        'Receipt',
        (bill) => bill.hasReceipt
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: buildReceipt(context, tenants[bill.tenantId]?.name, bill.receiptUrl),
              )
            : const Text('Unpaid'),
        sortKey: (bill) => bill.receiptUrl ?? '',
      ),
      TableColumn('Room', (bill) => Text(roomName(bill)), sortKey: (bill) => roomName(bill).toLowerCase()),
    ];
  }

  /// Each additional charge as "₱amount — note", so an amount stays next to its note at any width.
  Widget _additionalCharges(Bill bill) {
    if (bill.additionalCharges.isEmpty) return const Text('-');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final charge in bill.additionalCharges)
            Text(
              '${_currency.format(charge.amount)} — ${charge.description.isNotEmpty ? charge.description : '-'}',
              style: TextStyle(color: charge.amount < 0 ? Colors.red : null),
            ),
        ],
      ),
    );
  }

  Future<void> _showBillingDialog(BillingLoaded state, {Bill? bill}) async {
    final result = await showDialog<BillFormResult>(
      context: context,
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
    CustomSnackbar.show(context, bill != null ? 'Updating bill...' : 'Creating bill...', type: SnackBarType.loading);
    billingBloc.add(bill != null ? UpdateBill(bill.id, result.request, receipt: result.receipt) : AddBill(result.request, receipt: result.receipt));
  }

  Future<void> _deleteBill(int id) async {
    final completer = Completer<void>();
    billingBloc.add(DeleteBill(id, onComplete: completer));
    return completer.future;
  }

  void _showBillingDetailsDialog(Bill bill, _BillsView view) {
    final tenant = view.tenants[bill.tenantId];
    final room = view.rooms[_roomIdOf(bill, view.tenants)];

    showDialog(
      context: context,
      builder: (_) => BillingDetailsDialog(
        bill: bill,
        tenantName: tenant?.name ?? 'Unknown Tenant',
        roomName: room?.name ?? 'Unknown Room',
        consumption: bill.consumption.toString(),
        date: _dateFormat.format(bill.createdAt),
      ),
    );
  }

  /// Only data loads change what the page shows; action results are reported by the listener.
  static bool _shows(BillingState state) => state is BillingInitial || state is BillingLoading || state is BillingLoaded || state is BillingError;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Billing',
          showRefresh: true,
          onRefresh: () => billingBloc.add(LoadBills()),
          actions: [
            buildActiveToggleFilter(showActiveOnly: _showActiveOnly, onChanged: (value) => setState(() => _showActiveOnly = value)),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          builder: (context, authState) {
            if (authState is Unauthenticated) {
              return ErrorView(message: authState.message);
            }
            return BlocListener<BillingBloc, BillingState>(
              listener: (context, state) {
                if (state is BillingActionFailed) {
                  CustomSnackbar.show(context, state.message, type: SnackBarType.error, duration: const Duration(seconds: 6));
                } else if (state is BillingError) {
                  CustomSnackbar.hide(context);
                  // A failed load may mean the session expired; the auth check then shows the login error.
                  context.read<AuthBloc>().add(CheckAuthStatus());
                } else if (state is AddSuccess) {
                  CustomSnackbar.show(context, 'Bill created', type: SnackBarType.success);
                } else if (state is UpdateSuccess) {
                  CustomSnackbar.show(context, 'Bill updated', type: SnackBarType.success);
                } else if (state is DeleteSuccess) {
                  CustomSnackbar.show(context, 'Bill deleted', type: SnackBarType.success);
                }
              },
              child: BlocBuilder<BillingBloc, BillingState>(
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
            );
          },
        ),
        floatingActionButton: BlocBuilder<BillingBloc, BillingState>(
          buildWhen: (_, state) => _shows(state),
          builder: (context, state) => FloatingActionButton.extended(
            // Disabled until the billing data has loaded.
            onPressed: state is BillingLoaded ? () => _showBillingDialog(state) : null,
            backgroundColor: state is BillingLoaded ? null : Colors.grey,
            label: const Text('Generate New Bill'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _BillsView view) {
    final state = view.state;
    // Wider than other pages: the bill table has ten columns.
    return ResponsiveCenter(
      maxWidth: 1600,
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
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No bills found')),
                          ),
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
                        // Narrower screens get cards: the table needs about this much width.
                        tableMinWidth: 1240,
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
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showBillingDialog(view.state, bill: bill),
          ),
        ),
        IconButton(
          tooltip: 'Delete bill',
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => showConfirmationAction(
            context: context,
            messenger: ScaffoldMessenger.of(context),
            confirmTitle: 'Delete Bill',
            confirmContent: 'Are you sure you want to delete this bill? Its receipt is deleted too.',
            onConfirmed: () => _deleteBill(bill.id),
          ),
        ),
      ],
    );
  }
}
