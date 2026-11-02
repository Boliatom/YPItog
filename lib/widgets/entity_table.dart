import 'package:flutter/material.dart';

import '../models/catalog_entity.dart';
import 'card_grid.dart';

class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
    this.optional = false,
  });

  final String label;

  final String? sortField;
  final bool numeric;

  final bool optional;
  final Widget Function(T item) build;
}

class EntityTable<T extends CatalogEntity> extends StatefulWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    this.selected = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.onOpen,
    this.actions,
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final Set<String> selected;

  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<bool>? onSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;

  final void Function(T item)? onOpen;
  final List<Widget> Function(T item)? actions;

  static const fullWidth = 1280.0;

  @override
  State<EntityTable<T>> createState() => _EntityTableState<T>();
}

class _EntityTableState<T extends CatalogEntity> extends State<EntityTable<T>> {
  Widget _cell(BuildContext context, T item, Widget content) {
    if (!item.isDeleted) return content;
    final scheme = Theme.of(context).colorScheme;
    return DefaultTextStyle.merge(
      style: TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.5),
        decoration: TextDecoration.lineThrough,
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < EntityTable.fullWidth;
        return _table(context, [
          for (final column in widget.columns)
            if (!(tight && column.optional)) column,
        ]);
      },
    );
  }

  Widget _table(BuildContext context, List<TableColumnSpec<T>> columns) {
    final selectable = widget.onToggleSelect != null;
    final sortIndex = columns.indexWhere(
      (c) => c.sortField != null && c.sortField == widget.sortField,
    );
    final active = widget.items.where((e) => !e.isDeleted).toList();
    final allSelected =
        active.isNotEmpty &&
        active.every((e) => widget.selected.contains(e.id));

    return TwoDimensionalScroll(
      child: DataTable(
        key: ValueKey(Object.hashAll(widget.items.map((e) => e.id))),
        showCheckboxColumn: selectable,
        onSelectAll: selectable
            ? (value) => widget.onSelectAll?.call(value ?? !allSelected)
            : null,
        sortColumnIndex: sortIndex == -1 ? null : sortIndex,
        sortAscending: widget.sortAscending,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        columnSpacing: 20,
        horizontalMargin: 16,
        columns: [
          for (final column in columns)
            DataColumn(
              label: Text(
                column.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              numeric: column.numeric,
              tooltip: column.sortField == null
                  ? null
                  : 'Сортировать: ${column.label}',
              onSort: column.sortField == null || widget.onSort == null
                  ? null
                  : (_, _) => widget.onSort!(column.sortField!),
            ),
          if (widget.actions != null) const DataColumn(label: Text('Действия')),
        ],
        rows: [
          for (final item in widget.items)
            DataRow(
              key: ValueKey('row-${item.id}'),
              selected: widget.selected.contains(item.id),
              onSelectChanged: selectable && !item.isDeleted
                  ? (_) => widget.onToggleSelect!(item.id)
                  : null,
              cells: [
                for (var i = 0; i < columns.length; i++)
                  DataCell(
                    _cell(context, item, columns[i].build(item)),
                    onTap: i == 0 && widget.onOpen != null
                        ? () => widget.onOpen!(item)
                        : null,
                  ),
                if (widget.actions != null)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.actions!(item),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class EntityCardList<T extends CatalogEntity> extends StatelessWidget {
  const EntityCardList({
    super.key,
    required this.items,
    required this.title,
    required this.subtitle,
    this.columns = 1,
    this.selected = const {},
    this.onToggleSelect,
    this.onOpen,
    this.actions,
  });

  final List<T> items;
  final String Function(T item) title;
  final String Function(T item) subtitle;
  final int columns;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final void Function(T item)? onOpen;
  final List<Widget> Function(T item)? actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CardGrid<T>(
      items: items,
      columns: columns,
      itemBuilder: (context, item) {
        final deleted = item.isDeleted;
        final textStyle = deleted
            ? TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.5),
                decoration: TextDecoration.lineThrough,
              )
            : null;
        return Card(
          key: ValueKey('card-${item.id}'),
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onOpen == null ? null : () => onOpen!(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onToggleSelect != null)
                        Checkbox(
                          semanticLabel: 'Выбрать: ${title(item)}',
                          value: selected.contains(item.id),
                          onChanged: deleted
                              ? null
                              : (_) => onToggleSelect!(item.id),
                        )
                      else
                        const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title(item),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.merge(textStyle),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle(item),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant)
                                    .merge(textStyle),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (actions != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Wrap(children: actions!(item)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
