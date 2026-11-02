enum FieldKind {
  text,
  longText,
  integer,
  number,
  boolean,
  date,
  dateTime,
  select,
  relation,
  relations,
  email,
  phone,
}

class Option {
  const Option(this.value, this.label);

  final String value;
  final String label;
}

class FieldDef {
  const FieldDef(
    this.key,
    this.label,
    this.kind, {
    this.required = false,
    this.minLength,
    this.maxLength,
    this.min,
    this.max,
    this.pattern,
    this.patternMessage,
    this.options = const [],
    this.target,
    this.hint,
    this.inList = false,
    this.sortable = false,
    this.narrowedBy,
    this.immutable = false,
    this.pastOnly = false,
    this.unit,
    this.computed = false,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final num? min;
  final num? max;
  final String? pattern;
  final String? patternMessage;
  final List<Option> options;

  final String? target;
  final String? hint;

  final bool inList;
  final bool sortable;

  final String? narrowedBy;

  final bool immutable;

  final bool pastOnly;

  final String? unit;

  final bool computed;

  bool get isRelation =>
      kind == FieldKind.relation || kind == FieldKind.relations;

  bool get isNumeric => kind == FieldKind.integer || kind == FieldKind.number;

  String optionLabel(String value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }
}

enum FilterType {
  refEquals,
  optionEquals,
  numMin,
  numMax,
  dateFrom,
  dateTo,
  refContains,
}

class FilterDef {
  const FilterDef(
    this.param,
    this.label,
    this.type,
    this.field, {
    this.target,
    this.options = const [],
  });

  final String param;
  final String label;
  final FilterType type;
  final String field;
  final String? target;
  final List<Option> options;
}
