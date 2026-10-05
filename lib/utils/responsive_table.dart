import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// A column of a [ResponsiveTable]: its label, its cell, and (when sortable) the value it sorts by.
class TableColumn<T> {
  final String label;
  final Widget Function(T item) cell;
  final Comparable<Object?> Function(T item)? sortKey;
  final bool numeric;

  const TableColumn(this.label, this.cell, {this.sortKey, this.numeric = false});
}

/// [items] sorted by [column] (a copy; equal items keep their order). Unsortable columns leave the order as is.
List<T> sortItems<T>(List<T> items, TableColumn<T> column, {required bool ascending}) {
  final key = column.sortKey;
  if (key == null) return items;
  final keyed = [for (var i = 0; i < items.length; i++) (i, key(items[i]), items[i])];
  keyed.sort((a, b) {
    final byKey = a.$2.compareTo(b.$2);
    if (byKey != 0) return ascending ? byKey : -byKey;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, _, item) in keyed) item];
}

/// [items] (already sorted) as a sortable [DataTable] when at least [tableMinWidth] wide (so the table never
/// scrolls sideways), and as cards otherwise: the [titleColumn] as the card's title, the other columns as
/// label/value rows, sorted with a "Sort by" menu.
/// Tapping a row or card opens [onTap] (the details, whose text can be copied); the list's own text isn't selectable,
/// so a click always opens the details instead of starting a selection.
/// It scrolls itself and is always scrollable, so it works under a [RefreshIndicator].
class ResponsiveTable<T> extends StatelessWidget {
  final List<T> items;
  final List<TableColumn<T>> columns;
  final Widget Function(T item) actions;
  final void Function(T item) onTap;
  final int sortColumn;
  final bool sortAscending;
  final void Function(int column, bool ascending) onSort;
  final int titleColumn;
  final double tableMinWidth;

  const ResponsiveTable({
    super.key,
    required this.items,
    required this.columns,
    required this.actions,
    required this.onTap,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    this.titleColumn = 0,
    this.tableMinWidth = WindowSize.mediumMin,
  });

  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= tableMinWidth ? _table(context) : _cards(context)),
  );

  Widget _table(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 28,
          sortColumnIndex: sortColumn + 1,
          sortAscending: sortAscending,
          // Rows grow with multi-line cells (e.g. several additional charges).
          dataRowMaxHeight: double.infinity,
          columns: [
            const DataColumn(label: Text('Actions')),
            for (final (i, column) in columns.indexed)
              DataColumn(
                label: Text(column.label),
                numeric: column.numeric,
                onSort: column.sortKey == null ? null : (_, ascending) => onSort(i, ascending),
              ),
          ],
          rows: [
            for (final item in items)
              DataRow(
                onSelectChanged: (_) => onTap(item),
                cells: [DataCell(actions(item)), for (final column in columns) DataCell(column.cell(item))],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cards(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _sortBar(context);
        final item = items[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => onTap(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          child: columns[titleColumn].cell(item),
                        ),
                      ),
                      actions(item),
                    ],
                  ),
                  for (final (i, column) in columns.indexed)
                    if (i != titleColumn)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 128, child: Text(column.label, style: labelStyle)),
                            Expanded(child: column.cell(item)),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sortBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('Sort by'),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: sortColumn,
              items: [
                for (final (i, column) in columns.indexed)
                  if (column.sortKey != null)
                    DropdownMenuItem(
                      value: i,
                      child: Text(column.label, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (column) => onSort(column!, sortAscending),
            ),
          ),
          IconButton(
            tooltip: sortAscending ? 'Ascending' : 'Descending',
            icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => onSort(sortColumn, !sortAscending),
          ),
        ],
      ),
    );
  }
}
