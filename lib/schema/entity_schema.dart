import 'package:flutter/material.dart';

import '../core/date_format.dart';
import '../models/json_values.dart';
import '../models/rec.dart';
import 'field_def.dart';

typedef Draft = Map<String, Object?>;

typedef SchemaLookup = EntitySchema Function(String collection);

final RegExp _emailRule = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

class EntitySchema {
  const EntitySchema({
    required this.collection,
    required this.titlePlural,
    required this.titleSingular,
    required this.accusative,
    required this.icon,
    required this.fields,
    required this.searchFields,
    required this.searchLabel,
    required this.defaultSort,
    required this.title,
    required this.subtitle,
    this.filters = const [],
    this.defaultAscending = true,
    this.extraValidate,
    this.sectionName,
  });

  final String collection;
  final String titlePlural;
  final String titleSingular;
  final String accusative;
  final IconData icon;
  final List<FieldDef> fields;
  final List<String> searchFields;
  final String searchLabel;
  final String defaultSort;
  final bool defaultAscending;
  final List<FilterDef> filters;

  final String Function(Rec rec) title;
  final String Function(Rec rec) subtitle;

  final Map<String, String> Function(Map<String, Object?> values)?
  extraValidate;

  final String? sectionName;

  String get section => sectionName ?? collection;
  String get path => '/$section';

  Iterable<FieldDef> get relationFields => fields.where((f) => f.isRelation);

  Set<String> get sortableKeys => {
    for (final f in fields)
      if (f.sortable) f.key,
    'created',
  };

  FieldDef? field(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  FilterDef? filter(String param) {
    for (final f in filters) {
      if (f.param == param) return f;
    }
    return null;
  }

  String get expandParam => relationFields.map((f) => f.key).join(',');

  Rec parse(Map<String, dynamic> json, SchemaLookup lookup) {
    final values = <String, Object?>{};
    for (final f in fields) {
      values[f.key] = _read(f, json[f.key]);
    }
    values['deletedAt'] = _readDate(json['deletedAt']);
    final labels = <String, List<String>>{};
    final expand = asMap(json['expand']);
    if (expand != null) {
      for (final f in relationFields) {
        final raw = expand[f.key];
        final target = lookup(f.target!);
        final list = raw is List ? raw : (raw == null ? const [] : [raw]);
        labels[f.key] = [
          for (final item in list)
            if (asMap(item) != null)
              target.title(target.parse(asMap(item)!, lookup)),
        ];
      }
    }
    return Rec(
      collection: collection,
      id: asString(json['id']),
      values: values,
      labels: labels,
      created: asDate(json['created']),
      updated: asDate(json['updated']),
    );
  }

  Object? _read(FieldDef f, Object? raw) {
    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.longText:
      case FieldKind.email:
      case FieldKind.phone:
      case FieldKind.select:
        return asString(raw);
      case FieldKind.integer:
        return asIntOrNull(raw);
      case FieldKind.number:
        return raw is num ? raw : num.tryParse(asString(raw));
      case FieldKind.boolean:
        return raw == true;
      case FieldKind.date:
        return _readDate(raw);
      case FieldKind.dateTime:
        return asDate(raw)?.toLocal();
      case FieldKind.relation:
        return asString(raw);
      case FieldKind.relations:
        return raw is List ? [for (final v in raw) '$v'] : <String>[];
    }
  }

  static DateTime? _readDate(Object? raw) {
    final parsed = asDate(raw);
    if (parsed == null) return null;
    final utc = parsed.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  Map<String, Object?> toBody(Map<String, Object?> values) {
    final body = <String, Object?>{};
    for (final entry in values.entries) {
      final f = field(entry.key);
      final value = entry.value;
      if (entry.key == 'deletedAt') {
        body['deletedAt'] = value is DateTime
            ? value.toUtc().toIso8601String()
            : '';
        continue;
      }
      if (f == null) continue;
      switch (f.kind) {
        case FieldKind.date:
        case FieldKind.dateTime:
          body[f.key] = value is DateTime
              ? value.toUtc().toIso8601String()
              : '';
        case FieldKind.integer:
        case FieldKind.number:
          body[f.key] = value;
        case FieldKind.boolean:
          body[f.key] = value == true;
        case FieldKind.relations:
          body[f.key] = value is List ? value : <String>[];
        default:
          body[f.key] = value ?? '';
      }
    }
    return body;
  }

  Draft draftFrom(Rec? rec) {
    final draft = <String, Object?>{};
    for (final f in fields) {
      final value = rec?.values[f.key];
      switch (f.kind) {
        case FieldKind.integer:
        case FieldKind.number:
          draft[f.key] = value == null ? '' : _numText(value as num);
        case FieldKind.boolean:
          draft[f.key] = value == null ? true : value == true;
        case FieldKind.date:
        case FieldKind.dateTime:
          draft[f.key] = value is DateTime ? value : null;
        case FieldKind.relation:
          draft[f.key] = (value is String && value.isNotEmpty) ? value : null;
        case FieldKind.relations:
          draft[f.key] = value is List
              ? [for (final v in value) '$v']
              : <String>[];
        case FieldKind.select:
          draft[f.key] = (value is String && value.isNotEmpty) ? value : null;
        default:
          draft[f.key] = value == null ? '' : '$value';
      }
    }
    return draft;
  }

  Map<String, Object?> valuesFrom(Draft draft) {
    final values = <String, Object?>{};
    for (final f in fields) {
      final value = draft[f.key];
      switch (f.kind) {
        case FieldKind.integer:
          values[f.key] = int.tryParse('${value ?? ''}'.trim());
        case FieldKind.number:
          values[f.key] = num.tryParse(
            '${value ?? ''}'.trim().replaceAll(',', '.'),
          );
        case FieldKind.boolean:
          values[f.key] = value == true;
        case FieldKind.date:
        case FieldKind.dateTime:
          values[f.key] = value is DateTime ? value : null;
        case FieldKind.relation:
        case FieldKind.select:
          values[f.key] = value is String ? value : '';
        case FieldKind.relations:
          values[f.key] = value is List
              ? [for (final v in value) '$v']
              : <String>[];
        default:
          values[f.key] = '${value ?? ''}'.trim();
      }
    }
    return values;
  }

  String? validateField(FieldDef f, Object? value) {
    switch (f.kind) {
      case FieldKind.boolean:
        return null;
      case FieldKind.date:
      case FieldKind.dateTime:
        if (value is! DateTime) return f.required ? 'Укажите значение' : null;
        if (f.pastOnly && value.isAfter(DateTime.now())) {
          return 'Дата не может быть в будущем';
        }
        return null;
      case FieldKind.select:
        final text = value is String ? value : '';
        if (text.isEmpty) return f.required ? 'Выберите значение' : null;
        return f.options.any((o) => o.value == text)
            ? null
            : 'Недопустимое значение';
      case FieldKind.relation:
        final text = value is String ? value : '';
        return (text.isEmpty && f.required) ? 'Выберите значение' : null;
      case FieldKind.relations:
        final list = value is List ? value : const [];
        return (list.isEmpty && f.required) ? 'Выберите хотя бы одно' : null;
      case FieldKind.integer:
      case FieldKind.number:
        final text = '${value ?? ''}'.trim().replaceAll(',', '.');
        if (text.isEmpty) return f.required ? 'Введите число' : null;
        final number = f.kind == FieldKind.integer
            ? int.tryParse(text)
            : num.tryParse(text);
        if (number == null) {
          return f.kind == FieldKind.integer
              ? 'Нужно целое число'
              : 'Нужно число';
        }
        if (f.min != null && number < f.min!) {
          return f.max != null
              ? 'От ${f.min} до ${f.max}'
              : 'Не меньше ${f.min}';
        }
        if (f.max != null && number > f.max!) {
          return f.min != null
              ? 'От ${f.min} до ${f.max}'
              : 'Не больше ${f.max}';
        }
        return null;
      default:
        final text = '${value ?? ''}'.trim();
        if (text.isEmpty) return f.required ? 'Обязательное поле' : null;
        if (f.minLength != null && text.length < f.minLength!) {
          return 'Не короче ${f.minLength} символов';
        }
        if (f.maxLength != null && text.length > f.maxLength!) {
          return 'Не длиннее ${f.maxLength} символов';
        }
        if (f.kind == FieldKind.email && !_emailRule.hasMatch(text)) {
          return 'Некорректный адрес почты';
        }
        if (f.kind == FieldKind.phone) {
          final digits = text.replaceAll(RegExp(r'\D'), '');
          final ok =
              RegExp(r'^\+?[\d\s\-()]+$').hasMatch(text) &&
              digits.length >= 7 &&
              digits.length <= 15;
          if (!ok) return 'Некорректный номер телефона';
        }
        if (f.pattern != null && !RegExp(f.pattern!).hasMatch(text)) {
          return f.patternMessage ?? 'Недопустимый формат';
        }
        return null;
    }
  }

  Map<String, String> validate(Draft draft) {
    final errors = <String, String>{};
    for (final f in fields) {
      final message = validateField(f, draft[f.key]);
      if (message != null) errors[f.key] = message;
    }
    if (errors.isEmpty && extraValidate != null) {
      errors.addAll(extraValidate!(valuesFrom(draft)));
    }
    return errors;
  }

  String format(Rec rec, FieldDef f) {
    final value = rec.values[f.key];
    switch (f.kind) {
      case FieldKind.boolean:
        return value == true ? 'Да' : 'Нет';
      case FieldKind.date:
        return value is DateTime ? formatDay(value) : '—';
      case FieldKind.dateTime:
        return value is DateTime ? formatDateTime(value) : '—';
      case FieldKind.select:
        final text = value is String ? value : '';
        return text.isEmpty ? '—' : f.optionLabel(text);
      case FieldKind.relation:
      case FieldKind.relations:
        final label = rec.labelOf(f.key);
        if (label.isNotEmpty) return label;
        return rec.refs(f.key).isEmpty && rec.ref(f.key).isEmpty ? '—' : '…';
      case FieldKind.integer:
      case FieldKind.number:
        if (value is! num) return '—';
        final text = _numText(value);
        return f.unit == null ? text : '$text ${f.unit}';
      default:
        final text = '${value ?? ''}'.trim();
        return text.isEmpty ? '—' : text;
    }
  }
}

String _numText(num value) {
  if (value is int || value == value.roundToDouble()) {
    return '${value.round()}';
  }
  return value.toStringAsFixed(2);
}

String numText(num value) => _numText(value);
