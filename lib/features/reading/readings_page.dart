import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/auth/auth_state.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_bloc.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_event.dart';
import 'package:m18_residences_admin/features/reading/bloc/reading_state.dart';
import 'package:m18_residences_admin/features/reading/widgets/reading_details_dialog.dart';
import 'package:m18_residences_admin/features/reading/widgets/reading_form_dialog.dart';
import 'package:m18_residences_admin/utils/confirmation_action.dart';
import 'package:m18_residences_admin/utils/custom_add_button.dart';
import 'package:m18_residences_admin/utils/custom_snackbar.dart';
import 'package:m18_residences_admin/utils/responsive_table.dart';
import 'package:m18_residences_admin/utils/shared_widgets.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class ReadingsPage extends StatefulWidget {
  const ReadingsPage({super.key});

  @override
  ReadingsPageState createState() => ReadingsPageState();
}

/// The loaded data indexed by id, and the readings shown for the current filters and sort.
class _ReadingsView {
  final ReadingLoaded state;
  final Object settings;
  final Map<int, Tenant> tenants;
  final Map<int, Room> rooms;
  final List<TableColumn<Reading>> columns;
  final List<Reading> readings;

  const _ReadingsView(this.state, this.settings, this.tenants, this.rooms, this.columns, this.readings);
}

class ReadingsPageState extends State<ReadingsPage> {
  static final _dateFormat = DateFormat('MMM d, yyyy');

  /// Index of the Date column in [_columns], the default sort (newest first).
  static const _dateColumn = 4;

  late final ReadingBloc readingBloc = context.read<ReadingBloc>();
  bool _showActiveOnly = true;

  int? _filterRoomId;
  int? _filterTenantId;
  int? _filterYear = DateTime.now().year;
  int? _filterMonth = DateTime.now().month;
  int _sortColumn = _dateColumn;
  bool _sortAscending = false;

  /// Recomputed only when the data, the filters or the sort change, not on every build.
  _ReadingsView? _view;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(CheckAuthStatus());
    readingBloc.add(LoadReadings());
  }

  _ReadingsView _viewOf(ReadingLoaded state) {
    final settings = (_showActiveOnly, _filterRoomId, _filterTenantId, _filterYear, _filterMonth, _sortColumn, _sortAscending);
    final cached = _view;
    if (cached != null && identical(cached.state, state) && cached.settings == settings) return cached;

    final tenants = {for (final t in state.tenants) t.id: t};
    final rooms = {for (final r in state.rooms) r.id: r};
    final columns = _columns(tenants, rooms);
    final shown = state.readings.where((reading) {
      if (_showActiveOnly && !(tenants[reading.tenantId]?.isActive ?? false)) return false;
      if (_filterRoomId != null && reading.roomId != _filterRoomId) return false;
      if (_filterTenantId != null && reading.tenantId != _filterTenantId) return false;
      if (_filterYear != null && reading.createdAt.year != _filterYear) return false;
      if (_filterMonth != null && reading.createdAt.month != _filterMonth) return false;
      return true;
    }).toList();
    return _view = _ReadingsView(state, settings, tenants, rooms, columns, sortItems(shown, columns[_sortColumn], ascending: _sortAscending));
  }

  List<TableColumn<Reading>> _columns(Map<int, Tenant> tenants, Map<int, Room> rooms) {
    String tenantName(Reading reading) => tenants[reading.tenantId]?.name ?? 'Unknown Tenant';
    String roomName(Reading reading) => rooms[reading.roomId]?.name ?? 'Unknown Room';

    return [
      TableColumn('Tenant', (reading) => Text(tenantName(reading)), sortKey: (reading) => tenantName(reading).toLowerCase()),
      TableColumn('Previous (kWh)', (reading) => Text('${reading.prevReading}'), sortKey: (reading) => reading.prevReading, numeric: true),
      TableColumn('Current (kWh)', (reading) => Text('${reading.currReading}'), sortKey: (reading) => reading.currReading, numeric: true),
      TableColumn('Consumption (kWh)', (reading) => Text('${reading.consumption}'), sortKey: (reading) => reading.consumption, numeric: true),
      TableColumn('Date', (reading) => Text(_dateFormat.format(reading.createdAt)), sortKey: (reading) => reading.createdAt),
      TableColumn('Room', (reading) => Text(roomName(reading)), sortKey: (reading) => roomName(reading).toLowerCase()),
    ];
  }

  Future<void> _deleteReading(int id) async {
    final completer = Completer<void>();
    readingBloc.add(DeleteReading(id, onComplete: completer));
    return completer.future;
  }

  Future<void> _showReadingDialog(ReadingLoaded state, {Reading? reading}) async {
    final result = await showDialog<ReadingRequest>(
      context: context,
      builder: (context) => ReadingFormDialog(
        showActiveOnly: _showActiveOnly,
        selectedRoomId: _filterRoomId,
        selectedTenantId: _filterTenantId,
        reading: reading,
        rooms: state.rooms,
        tenants: state.tenants,
        readings: state.readings,
      ),
    );
    if (!mounted || result == null) return;

    // Replaced by the bloc's result (see the listener).
    CustomSnackbar.show(context, reading != null ? 'Updating reading...' : 'Adding reading...', type: SnackBarType.loading);
    readingBloc.add(reading != null ? UpdateReading(reading.id, result) : AddReading(result));
  }

  void _showReadingDetailsDialog(Reading reading, _ReadingsView view) {
    showDialog(
      context: context,
      builder: (context) => ReadingDetailsDialog(
        reading: reading,
        getTenantName: (id) => view.tenants[id]?.name ?? 'Unknown Tenant',
        getRoomName: (id) => view.rooms[id]?.name ?? 'Unknown Room',
        dateFormat: _dateFormat,
      ),
    );
  }

  /// Only data loads change what the page shows; action results are reported by the listener.
  static bool _shows(ReadingState state) => state is ReadingInitial || state is ReadingLoading || state is ReadingLoaded || state is ReadingError;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Electricity Readings',
          showRefresh: true,
          onRefresh: () => readingBloc.add(LoadReadings()),
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

            return BlocListener<ReadingBloc, ReadingState>(
              listener: (context, state) {
                if (state is ReadingActionFailed) {
                  CustomSnackbar.show(context, state.message, type: SnackBarType.error, duration: const Duration(seconds: 6));
                } else if (state is ReadingError) {
                  CustomSnackbar.hide(context);
                  // A failed load may mean the session expired; the auth check then shows the login error.
                  context.read<AuthBloc>().add(CheckAuthStatus());
                } else if (state is AddSuccess) {
                  CustomSnackbar.show(context, 'Reading created', type: SnackBarType.success);
                } else if (state is UpdateSuccess) {
                  CustomSnackbar.show(context, 'Reading updated', type: SnackBarType.success);
                } else if (state is DeleteSuccess) {
                  CustomSnackbar.show(context, 'Reading deleted', type: SnackBarType.success);
                }
              },
              child: BlocBuilder<ReadingBloc, ReadingState>(
                buildWhen: (_, state) => _shows(state),
                builder: (context, state) {
                  if (state is ReadingError) {
                    return ErrorView(message: state.message, onRetry: () => readingBloc.add(LoadReadings()));
                  }
                  if (state is! ReadingLoaded) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildContent(context, _viewOf(state));
                },
              ),
            );
          },
        ),
        floatingActionButton: BlocBuilder<ReadingBloc, ReadingState>(
          buildWhen: (_, state) => _shows(state),
          builder: (context, state) {
            if (state is ReadingLoaded) {
              return CustomAddButton(onPressed: () => _showReadingDialog(state), label: 'New Reading');
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _ReadingsView view) {
    final state = view.state;
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
                dates: state.readings.map((reading) => reading.createdAt),
                selectedYear: _filterYear,
                onYearChanged: (year) => setState(() => _filterYear = year),
              ),
              month: buildMonthFilter(selectedMonth: _filterMonth, onMonthChanged: (month) => setState(() => _filterMonth = month)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  readingBloc.add(LoadReadings());
                  await readingBloc.stream.firstWhere((s) => s is! ReadingLoading);
                },
                child: view.readings.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No readings found for the selected filters.')),
                          ),
                        ],
                      )
                    : ResponsiveTable<Reading>(
                        items: view.readings,
                        columns: view.columns,
                        sortColumn: _sortColumn,
                        sortAscending: _sortAscending,
                        onSort: (column, ascending) => setState(() {
                          _sortColumn = column;
                          _sortAscending = ascending;
                        }),
                        // Narrower screens get cards: the table needs about this much width.
                        tableMinWidth: 900,
                        onTap: (reading) => _showReadingDetailsDialog(reading, view),
                        actions: (reading) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit reading',
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showReadingDialog(state, reading: reading),
                            ),
                            IconButton(
                              tooltip: 'Delete reading',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => showConfirmationAction(
                                context: context,
                                messenger: ScaffoldMessenger.of(context),
                                confirmTitle: 'Confirm Deletion',
                                confirmContent: 'Are you sure you want to delete this reading?',
                                onConfirmed: () => _deleteReading(reading.id),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
