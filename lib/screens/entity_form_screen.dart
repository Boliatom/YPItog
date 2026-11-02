import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/permission.dart';
import '../core/api_exceptions.dart';
import '../core/date_format.dart';
import '../core/layout.dart';
import '../core/navigation.dart';
import '../models/rec.dart';
import '../repositories/record_repository.dart';
import '../schema/entity_schema.dart';
import '../schema/field_def.dart';
import '../schema/schemas.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart' show LoadStatus;
import '../state/reference_cache.dart';
import '../state/unsaved_changes_guard.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({super.key, required this.schema, this.id});

  final EntitySchema schema;
  final String? id;

  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final UnsavedChangesGuard _guard;
  late final RecordRepository _repo;
  late final ReferenceCache _refs;

  EntitySchema get schema => widget.schema;
  bool get isEditing => widget.id != null;

  Draft _draft = {};
  Map<String, String> _errors = {};
  LoadStatus _status = LoadStatus.loading;
  String? _loadError;
  String? _banner;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _guard = context.read<UnsavedChangesGuard>()..reset();
    _repo = context.read<SalonRepositories>().of(schema.collection);
    _refs = context.read<ReferenceCache>();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _status = LoadStatus.loading;
      _loadError = null;
    });
    try {
      await Future.wait([
        for (final f in schema.relationFields) _refs.load(f.target!),
      ]);
      Rec? original;
      if (isEditing) {
        original = await _repo.findById(widget.id!);
        if (original == null) throw const NotFoundException();
      }
      if (!mounted) return;
      setState(() {
        _draft = schema.draftFrom(original);
        if (!isEditing && schema.collection == 'appointments') {
          _draft['status'] = 'new';
        }
        _status = LoadStatus.success;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _status = LoadStatus.error;
          _loadError = e.message;
        });
      }
    }
  }

  void _set(String key, Object? value) {
    setState(() {
      _draft = {..._draft, key: value};
      _errors = {..._errors}..remove(key);
      _banner = null;
      _dirty = true;
    });
    _guard.setDirty(true);
  }

  Future<void> _save() async {
    if (_saving) return;
    final errors = schema.validate(_draft);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() {
      _saving = true;
      _banner = null;
    });
    _guard.setSaving(true);
    try {
      final values = schema.valuesFrom(_draft)
        ..removeWhere((key, _) => schema.field(key)?.computed == true);
      if (isEditing) {
        await _repo.update(widget.id!, values);
      } else {
        await _repo.create(values);
      }
      _guard.setDirty(false);
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Изменения сохранены' : 'Запись создана'),
        ),
      );
      _leave();
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = {..._errors, ...e.errors};
        _banner = e.errors.isEmpty
            ? e.message
            : 'Сервер отклонил некоторые поля.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _banner = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
      _guard.setSaving(false);
    }
  }

  void _leave() => popOrGo(context, schema.path);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final title = isEditing
        ? 'Изменение: ${schema.titleSingular.toLowerCase()}'
        : 'Новая запись: ${schema.titleSingular.toLowerCase()}';
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        final leave = await _guard.confirm(context);
        if (leave && mounted) _leave();
      },
      child: SalonScaffold(
        title: title,
        section: schema.section,
        leading: IconButton(
          key: const ValueKey('form-back'),
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: _leave,
        ),
        body: switch (_status) {
          LoadStatus.idle || LoadStatus.loading => const LoadingPanel(),
          LoadStatus.error => ErrorPanel(
            message: _loadError ?? 'Неизвестная ошибка.',
            onRetry: _start,
          ),
          LoadStatus.success when !auth.can(Permission.editData) =>
            const EmptyPanel(
              icon: Icons.lock_outline,
              title: 'Нужны права на изменение',
              message: 'У вашей роли нет прав на изменение данных.',
            ),
          LoadStatus.success => _form(context),
        },
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxFormWidth),
          child: Card(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_banner != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _banner!,
                          key: const ValueKey('form-banner'),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                for (final f in schema.fields)
                  if (!f.computed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _field(context, f),
                    ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey('form-save'),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('form-cancel'),
                      onPressed: _saving ? null : _leave,
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, FieldDef f) {
    final error = _errors[f.key];
    final locked = isEditing && f.immutable;
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.kind) {
      case FieldKind.boolean:
        return SwitchListTile(
          key: ValueKey('field-${f.key}'),
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          value: _draft[f.key] == true,
          onChanged: (v) => _set(f.key, v),
        );
      case FieldKind.date:
      case FieldKind.dateTime:
        return _DateField(
          fieldKey: ValueKey('field-${f.key}'),
          label: label,
          value: _draft[f.key] as DateTime?,
          withTime: f.kind == FieldKind.dateTime,
          error: error,
          onChanged: (v) => _set(f.key, v),
        );
      case FieldKind.select:
        return DropdownButtonFormField<String>(
          key: ValueKey('field-${f.key}'),
          initialValue: _draft[f.key] as String?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, errorText: error),
          items: [
            for (final o in f.options)
              DropdownMenuItem(value: o.value, child: Text(o.label)),
          ],
          onChanged: (v) => _set(f.key, v),
        );
      case FieldKind.relation:
        final items = _refs.cached(f.target!);
        final current = _draft[f.key] as String?;
        return DropdownButtonFormField<String>(
          key: ValueKey('field-${f.key}'),
          initialValue: items.any((r) => r.id == current) ? current : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, errorText: error),
          items: [
            for (final r in items)
              DropdownMenuItem(
                value: r.id,
                child: Text(titleOf(r), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: locked ? null : (v) => _set(f.key, v),
        );
      case FieldKind.relations:
        return _MultiSelect(
          fieldKey: ValueKey('field-${f.key}'),
          label: label,
          error: error,
          options: _optionsFor(f),
          selected: List<String>.from(_draft[f.key] as List? ?? const []),
          onChanged: (v) => _set(f.key, v),
        );
      case FieldKind.integer:
      case FieldKind.number:
        return TextFormField(
          key: ValueKey('field-${f.key}'),
          initialValue: '${_draft[f.key] ?? ''}',
          keyboardType: TextInputType.numberWithOptions(
            decimal: f.kind == FieldKind.number,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              f.kind == FieldKind.number
                  ? RegExp(r'[0-9.,]')
                  : RegExp(r'[0-9]'),
            ),
          ],
          decoration: InputDecoration(
            labelText: label,
            helperText: f.hint,
            suffixText: f.unit,
            errorText: error,
          ),
          onChanged: (v) => _set(f.key, v),
        );
      default:
        return TextFormField(
          key: ValueKey('field-${f.key}'),
          initialValue: '${_draft[f.key] ?? ''}',
          maxLines: f.kind == FieldKind.longText ? 4 : 1,
          keyboardType: switch (f.kind) {
            FieldKind.email => TextInputType.emailAddress,
            FieldKind.phone => TextInputType.phone,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: label,
            helperText: f.hint,
            errorText: error,
          ),
          onChanged: (v) => _set(f.key, v),
        );
    }
  }

  List<Rec> _optionsFor(FieldDef f) {
    final all = _refs.cached(f.target!);
    final narrow = f.narrowedBy;
    if (narrow == null) return all;
    final chosen = _draft[narrow] as String?;
    if (chosen == null) return all;
    final owner = _refs
        .cached(schema.field(narrow)!.target!)
        .where((r) => r.id == chosen)
        .firstOrNull;
    if (owner == null) return all;
    final allowed = owner.refs(f.key).toSet();
    return [
      for (final r in all)
        if (allowed.contains(r.id)) r,
    ];
  }
}

class _MultiSelect extends StatelessWidget {
  const _MultiSelect({
    required this.fieldKey,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.error,
  });

  final Key fieldKey;
  final String label;
  final String? error;
  final List<Rec> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      key: fieldKey,
      decoration: InputDecoration(labelText: label, errorText: error),
      child: options.isEmpty
          ? const Text('Нет доступных вариантов')
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in options)
                  FilterChip(
                    key: ValueKey('chip-${r.id}'),
                    label: Text(titleOf(r)),
                    selected: selected.contains(r.id),
                    selectedColor: scheme.primaryContainer,
                    onSelected: (on) {
                      final next = [...selected];
                      on ? next.add(r.id) : next.remove(r.id);
                      onChanged(next);
                    },
                  ),
              ],
            ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.withTime,
    required this.onChanged,
    this.error,
  });

  final Key fieldKey;
  final String label;
  final DateTime? value;
  final bool withTime;
  final String? error;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value == null
        ? now
        : (withTime ? value! : utcDayToLocal(value!));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (day == null || !context.mounted) return;
    if (!withTime) {
      onChanged(DateTime.utc(day.year, day.month, day.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onChanged(DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Не выбрано'
        : (withTime ? formatDateTime(value) : formatDay(value));
    return InkWell(
      key: fieldKey,
      borderRadius: BorderRadius.circular(20),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(text),
      ),
    );
  }
}
