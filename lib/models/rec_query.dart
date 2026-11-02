import '../schema/entity_schema.dart';
import '../schema/field_def.dart';
import 'list_query.dart';

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,40}$');
final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class RecQuery extends ListQuery<RecQuery> {
  RecQuery({
    required this.schema,
    String? sortField,
    bool? sortAscending,
    super.search,
    super.page,
    super.size,
    super.includeDeleted,
    super.debug,
    this.filters = const {},
  }) : super(
         sortField: sortField ?? schema.defaultSort,
         sortAscending: sortAscending ?? schema.defaultAscending,
       );

  final EntitySchema schema;
  final Map<String, String> filters;

  @override
  String get defaultSortField => schema.defaultSort;

  @override
  bool get defaultAscending => schema.defaultAscending;

  @override
  Map<String, String> get filterParams => filters;

  factory RecQuery.fromParams(EntitySchema schema, Map<String, String> params) {
    final sort = parseSort(
      params['sort'],
      allowed: schema.sortableKeys,
      fallback: schema.defaultSort,
    );
    final hasSort = (params['sort'] ?? '').trim().isNotEmpty;
    final filters = <String, String>{};
    for (final def in schema.filters) {
      final raw = params[def.param]?.trim();
      if (raw == null || raw.isEmpty) continue;
      if (_valid(def, raw)) filters[def.param] = raw;
    }
    return RecQuery(
      schema: schema,
      sortField: hasSort ? sort.field : schema.defaultSort,
      sortAscending: hasSort ? sort.ascending : schema.defaultAscending,
      search: params['search']?.trim() ?? '',
      filters: filters,
      page: parsePage(params['page']),
      size: parsePageSize(params['size']),
      includeDeleted: parseFlag(params['includeDeleted']),
      debug: parseDebug(params),
    );
  }

  static bool _valid(FilterDef def, String raw) {
    switch (def.type) {
      case FilterType.refEquals:
      case FilterType.refContains:
        return _idPattern.hasMatch(raw);
      case FilterType.optionEquals:
        return def.options.any((o) => o.value == raw);
      case FilterType.numMin:
      case FilterType.numMax:
        return num.tryParse(raw) != null;
      case FilterType.dateFrom:
      case FilterType.dateTo:
        if (!_dayPattern.hasMatch(raw)) return false;
        final parsed = DateTime.tryParse(raw);
        return parsed != null &&
            parsed.month == int.parse(raw.substring(5, 7)) &&
            parsed.day == int.parse(raw.substring(8, 10));
    }
  }

  RecQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    Map<String, String>? filters,
    Map<String, String>? debug,
  }) => RecQuery(
    schema: schema,
    search: search ?? this.search,
    sortField: sortField ?? this.sortField,
    sortAscending: sortAscending ?? this.sortAscending,
    page: page ?? 1,
    size: size ?? this.size,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    filters: filters ?? this.filters,
    debug: debug ?? this.debug,
  );

  RecQuery withFilter(String param, String? value) {
    final next = Map<String, String>.of(filters);
    if (value == null || value.isEmpty) {
      next.remove(param);
    } else {
      next[param] = value;
    }
    return copyWith(filters: next);
  }

  @override
  RecQuery withCommon({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    Map<String, String>? debug,
  }) => RecQuery(
    schema: schema,
    search: search ?? this.search,
    sortField: sortField ?? this.sortField,
    sortAscending: sortAscending ?? this.sortAscending,
    page: page ?? this.page,
    size: size ?? this.size,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    filters: filters,
    debug: debug ?? this.debug,
  );

  @override
  RecQuery reset() => RecQuery(
    schema: schema,
    sortField: sortField,
    sortAscending: sortAscending,
    size: size,
    includeDeleted: includeDeleted,
    debug: debug,
  );
}
