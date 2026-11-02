import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/date_format.dart';
import '../models/rec_query.dart';
import '../schema/entity_schema.dart';
import '../schema/field_def.dart';
import '../schema/schemas.dart';
import '../state/reference_cache.dart';
import 'debounced_field.dart';

const _fieldWidth = 220.0;

class EntityFilters extends StatelessWidget {
  const EntityFilters({
    super.key,
    required this.schema,
    required this.query,
    required this.onChange,
    this.allowDeleted = false,
    this.hidden = const {},
  });

  final EntitySchema schema;
  final RecQuery query;
  final ValueChanged<RecQuery> onChange;
  final bool allowDeleted;
  final Set<String> hidden;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (schema.searchFields.isNotEmpty)
          DebouncedField(
            key: const ValueKey('filter-search'),
            value: query.search,
            label: schema.searchLabel,
            prefixIcon: Icons.search,
            width: 300,
            onChanged: (value) => onChange(query.copyWith(search: value)),
          ),
        for (final def in schema.filters)
          if (!hidden.contains(def.field))
            _FilterField(
              key: ValueKey('filter-${def.param}'),
              def: def,
              query: query,
              onChange: onChange,
            ),
        if (allowDeleted)
          FilterChip(
            key: const ValueKey('filter-deleted'),
            label: const Text('Показывать удалённые'),
            selected: query.includeDeleted,
            onSelected: (value) =>
                onChange(query.copyWith(includeDeleted: value)),
          ),
        if (query.hasFilters)
          TextButton.icon(
            key: const ValueKey('filter-reset'),
            onPressed: () => onChange(query.reset()),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Сбросить'),
          ),
      ],
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    super.key,
    required this.def,
    required this.query,
    required this.onChange,
  });

  final FilterDef def;
  final RecQuery query;
  final ValueChanged<RecQuery> onChange;

  @override
  Widget build(BuildContext context) {
    final value = query.filters[def.param] ?? '';
    switch (def.type) {
      case FilterType.refEquals:
      case FilterType.refContains:
        return _RefDropdown(
          def: def,
          value: value,
          onChanged: (v) => onChange(query.withFilter(def.param, v)),
        );
      case FilterType.optionEquals:
        return SizedBox(
          width: _fieldWidth,
          child: DropdownButtonFormField<String>(
            key: ValueKey('${def.param}-dropdown'),
            initialValue: value.isEmpty ? '' : value,
            isExpanded: true,
            decoration: InputDecoration(labelText: def.label),
            items: [
              const DropdownMenuItem(value: '', child: Text('Все')),
              for (final o in def.options)
                DropdownMenuItem(value: o.value, child: Text(o.label)),
            ],
            onChanged: (v) => onChange(query.withFilter(def.param, v)),
          ),
        );
      case FilterType.numMin:
      case FilterType.numMax:
        return DebouncedField(
          value: value,
          label: def.label,
          width: 160,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (v) => onChange(query.withFilter(def.param, v.trim())),
        );
      case FilterType.dateFrom:
      case FilterType.dateTo:
        return _DateFilter(
          def: def,
          value: value,
          onChanged: (v) => onChange(query.withFilter(def.param, v)),
        );
    }
  }
}

class _RefDropdown extends StatefulWidget {
  const _RefDropdown({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  final FilterDef def;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  State<_RefDropdown> createState() => _RefDropdownState();
}

class _RefDropdownState extends State<_RefDropdown> {
  @override
  void initState() {
    super.initState();
    context.read<ReferenceCache>().load(widget.def.target!).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ReferenceCache>().cached(widget.def.target!);
    final known = items.any((r) => r.id == widget.value);
    return SizedBox(
      width: _fieldWidth,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${widget.def.param}-dropdown'),
        initialValue: known ? widget.value : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: widget.def.label),
        items: [
          const DropdownMenuItem(value: '', child: Text('Все')),
          for (final r in items)
            DropdownMenuItem(
              value: r.id,
              child: Text(titleOf(r), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  final FilterDef def;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final parsed = value.isEmpty ? null : DateTime.tryParse(value);
    return SizedBox(
      width: _fieldWidth,
      child: OutlinedButton.icon(
        key: ValueKey('${def.param}-date'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: parsed ?? now,
            firstDate: DateTime(1940),
            lastDate: DateTime(now.year + 2, 12, 31),
          );
          if (picked != null) onChanged(_iso(picked));
        },
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
        label: Text(
          parsed == null
              ? def.label
              : '${def.label}: ${formatDay(DateTime.utc(parsed.year, parsed.month, parsed.day))}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
