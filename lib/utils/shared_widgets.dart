import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// The month electricity billed on [posted] was used: bills are posted early in a month for the month before's usage
/// (their room charge is for the posting month).
DateTime usageMonth(DateTime posted) => DateTime(posted.year, posted.month - 1);

/// "Active only" filter chip: hides inactive tenants (and their readings and bills) while selected.
Widget buildActiveToggleFilter({required bool showActiveOnly, required ValueChanged<bool> onChanged}) {
  return FilterChip(label: const Text('Active only'), selected: showActiveOnly, onSelected: onChanged);
}

Widget buildRoomFilter({
  required List<Room> rooms,
  required List<Tenant> tenants,
  required int? selectedRoomId,
  required int? selectedTenantId,
  required void Function(int? roomId, int? tenantId) onFilterChanged,
  String? label,
  String? semanticsId,
  String? Function(int?)? validator,
}) {
  return CustomDropdownForm<int>(
    label: label ?? 'Filter by Room',
    validator: validator,
    semanticsId: semanticsId,
    items: [
      const DropdownMenuItem(value: null, child: Text('All Rooms')),
      ...rooms.map((room) => DropdownMenuItem(value: room.id, child: Text(room.name))),
    ],
    value: selectedRoomId,
    onChanged: (value) {
      int? newRoomId = value;
      int? newTenantId = selectedTenantId;

      if (newRoomId == null) {
        newTenantId = null;
      } else if (newTenantId != null) {
        final tenant = tenants.firstWhereOrNull((t) => t.id == newTenantId);
        if (tenant == null || tenant.roomId != newRoomId) {
          newTenantId = null;
        }
      }
      onFilterChanged(newRoomId, newTenantId);
    },
  );
}

/// Tenant dropdown, listing the tenants of the selected room (all rooms when none is). Picking a tenant sets
/// the room to theirs only with [autoSelectRoom] (when generating a bill or adding a reading). With [allLabel]
/// (filters), the empty choice is selectable and means every tenant.
Widget buildTenantFilter({
  required List<Tenant> tenants,
  required int? selectedRoomId,
  required int? selectedTenantId,
  required bool showActiveOnly,
  required void Function(int? tenantId, int? roomId) onFilterChanged,
  bool autoSelectRoom = false,
  String? allLabel,
  String? label,
  String? semanticsId,
}) {
  final filteredTenants = tenants.where((t) {
    final matchesRoom = selectedRoomId == null || t.roomId == selectedRoomId;
    final matchesActive = !showActiveOnly || t.isActive || t.id == selectedTenantId;
    return matchesRoom && matchesActive;
  }).toList();

  return CustomDropdownForm<int>(
    label: label ?? 'Filter by Tenant',
    hint: allLabel ?? 'Choose a tenant',
    semanticsId: semanticsId,
    items: [
      DropdownMenuItem(value: null, enabled: allLabel != null, child: Text(allLabel ?? 'Choose a tenant')),
      ...filteredTenants.map((tenant) => DropdownMenuItem(value: tenant.id, child: Text(tenant.name))),
    ],
    value: selectedTenantId,
    onChanged: (tenantId) {
      final tenant = tenants.firstWhereOrNull((t) => t.id == tenantId);
      onFilterChanged(tenantId, autoSelectRoom && tenant != null ? tenant.roomId : selectedRoomId);
    },
    validator: allLabel != null ? null : (value) => value == null ? 'Please choose a tenant' : null,
  );
}

/// Year filter over the years of [dates] plus the current one (newest first); "All Years" is null.
Widget buildYearFilter({required Iterable<DateTime> dates, required int? selectedYear, required ValueChanged<int?> onYearChanged}) {
  final years = {DateTime.now().year, ...dates.map((d) => d.year)}.toList()..sort((a, b) => b.compareTo(a));

  return CustomDropdownForm<int>(
    label: 'Filter by Year',
    items: [
      const DropdownMenuItem(value: null, child: Text('All Years')),
      ...years.map((year) => DropdownMenuItem(value: year, child: Text(year.toString()))),
    ],
    value: selectedYear,
    onChanged: onYearChanged,
  );
}

/// Month filter (January to December); "All Months" is null.
Widget buildMonthFilter({required int? selectedMonth, required ValueChanged<int?> onMonthChanged}) {
  return CustomDropdownForm<int>(
    label: 'Filter by Month',
    items: [
      const DropdownMenuItem(value: null, child: Text('All Months')),
      for (var month = 1; month <= 12; month++) DropdownMenuItem(value: month, child: Text(DateFormat.MMMM().format(DateTime(0, month)))),
    ],
    value: selectedMonth,
    onChanged: onMonthChanged,
  );
}

/// Room, tenant, year and month filters: two rows on phones, one row on wider screens.
Widget buildFilterBar(BuildContext context, {required Widget room, required Widget tenant, required Widget year, required Widget month}) {
  const gap = SizedBox(width: 12);
  if (context.windowSize.isCompact) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: room),
            gap,
            Expanded(child: tenant),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: year),
            gap,
            Expanded(child: month),
          ],
        ),
      ],
    );
  }
  return Row(
    children: [
      Expanded(child: room),
      gap,
      Expanded(child: tenant),
      gap,
      Expanded(child: year),
      gap,
      Expanded(child: month),
    ],
  );
}

/// "View receipt" / "View payment" button for bill [billId]'s file (nothing when there is none: [fileUrl] null or
/// empty); the signed URL is fetched by bill id when it is opened. [iconOnly] and [label] as in [BillFileButton].
Widget buildBillFile(
  BuildContext context,
  BillFileKind kind,
  int billId,
  String? tenantName,
  String? fileUrl, {
  bool iconOnly = false,
  String? label,
}) {
  return BillFileButton(
    kind: kind,
    billId: billId,
    tenantName: tenantName,
    fileUrl: fileUrl,
    iconOnly: iconOnly,
    label: label,
    fetchSignedFile: context.read<AuthBloc>().authApi.signedBillFileUrl,
  );
}
