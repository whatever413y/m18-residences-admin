import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

/// A column of a [ResponsiveTable]: its label, its cell, and (when sortable) the value it sorts by.
///
/// Columns can come and go with the width: the table shows a column only when it is at least [minWidth] wide
/// (`double.infinity`: cards only), and cards leave out columns with [inCards] false. [tableCell] replaces [cell] in
/// the table (e.g. a denser version).
class TableColumn<T> {
  final String label;
  final Widget Function(T item) cell;
  final Widget Function(T item)? tableCell;
  final Comparable<Object?> Function(T item)? sortKey;
  final bool numeric;
  final double minWidth;
  final bool inCards;

  const TableColumn(this.label, this.cell, {this.sortKey, this.numeric = false, this.tableCell, this.minWidth = 0, this.inCards = true});
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

/// [items] (already sorted) as a sortable [DataTable] when at least [tableMinWidth] wide, with the columns that fit
/// (see [TableColumn.minWidth]), and as cards otherwise: the [titleColumn] as the card's title, the other columns as
/// label/value rows, sorted with a "Sort by" menu. Should a table still be wider than the page (e.g. with large
/// text), it scrolls sideways with its scrollbar always shown at the bottom of the view.
/// Tapping a row or card opens [onTap] (the details, whose text can be copied); the list's own text isn't selectable,
/// so a click always opens the details instead of starting a selection.
/// It scrolls itself and is always scrollable, so it works under a [RefreshIndicator].
class ResponsiveTable<T> extends StatefulWidget {
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
    this.columnSpacing = 28,
  });

  final double columnSpacing;

  @override
  State<ResponsiveTable<T>> createState() => _ResponsiveTableState<T>();
}

class _ResponsiveTableState<T> extends State<ResponsiveTable<T>> {
  final _horizontal = ScrollController();

  List<T> get items => widget.items;
  List<TableColumn<T>> get columns => widget.columns;
  int get sortColumn => widget.sortColumn;
  bool get sortAscending => widget.sortAscending;
  int get titleColumn => widget.titleColumn;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= widget.tableMinWidth ? _table(context, constraints.maxWidth) : _cards(context),
    ),
  );

  Widget _table(BuildContext context, double width) {
    final shown = [
      for (final (i, column) in columns.indexed)
        if (column.minWidth <= width) (i, column),
    ];
    final sortIndex = shown.indexWhere((c) => c.$1 == sortColumn);
    // The sideways scrollbar belongs to the inner (depth 1) scroll view but is drawn on the outer one's box, so it
    // stays at the bottom of the view instead of the bottom of a long table.
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: true,
      notificationPredicate: (notification) => notification.depth == 1,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            // At least as wide as the page, so the table's card spans it.
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: widget.columnSpacing,
                decoration: BoxDecoration(
                  color: AppTheme.panelColor(Theme.of(context).colorScheme),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                // A sort column not shown at this width marks no header (the rows stay sorted by it).
                sortColumnIndex: sortIndex < 0 ? null : sortIndex + 1,
                sortAscending: sortAscending,
                // Rows grow with multi-line cells (e.g. several additional charges).
                dataRowMaxHeight: double.infinity,
                columns: [
                  const DataColumn(label: Text('Actions')),
                  for (final (i, column) in shown)
                    DataColumn(
                      label: Text(column.label),
                      numeric: column.numeric,
                      onSort: column.sortKey == null ? null : (_, ascending) => widget.onSort(i, ascending),
                    ),
                ],
                rows: [
                  for (final item in items)
                    DataRow(
                      onSelectChanged: (_) => widget.onTap(item),
                      cells: [DataCell(widget.actions(item)), for (final (_, column) in shown) DataCell((column.tableCell ?? column.cell)(item))],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cards(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _sortBar(context);
        final item = items[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => widget.onTap(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle.merge(style: Theme.of(context).textTheme.titleMedium, child: columns[titleColumn].cell(item)),
                      ),
                      widget.actions(item),
                    ],
                  ),
                  // Label above value, two (or more) per row, so a card stays short on phones.
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final perRow = (constraints.maxWidth / 170).floor().clamp(2, 4);
                        final width = (constraints.maxWidth - 16 * (perRow - 1)) / perRow;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            for (final (i, column) in columns.indexed)
                              if (i != titleColumn && column.inCards)
                                SizedBox(
                                  width: width,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(column.label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      DefaultTextStyle.merge(
                                        style: const TextStyle(fontFeatures: AppTheme.tabularFigures),
                                        child: column.cell(item),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        );
                      },
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
                  if (column.sortKey != null && column.inCards)
                    DropdownMenuItem(
                      value: i,
                      child: Text(column.label, overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (column) => widget.onSort(column!, sortAscending),
            ),
          ),
          IconButton(
            tooltip: sortAscending ? 'Ascending' : 'Descending',
            icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => widget.onSort(sortColumn, !sortAscending),
          ),
        ],
      ),
    );
  }
}
