import 'package:flutter/foundation.dart';

const pageSizes = [10, 25, 50];

abstract class ListQuery<Q extends ListQuery<Q>> {
  const ListQuery({
    this.search = '',
    required this.sortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.debug = const {},
  });

  final String search;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  final Map<String, String> debug;

  String get defaultSortField;

  bool get defaultAscending => true;

  Map<String, String> get filterParams;

  Q withCommon({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    Map<String, String>? debug,
  });

  Q reset();

  bool get hasFilters => search.trim().isNotEmpty || filterParams.isNotEmpty;

  String get sortParam => '$sortField,${sortAscending ? 'asc' : 'desc'}';

  Map<String, String> toUrlParams() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    ...filterParams,
    if (sortField != defaultSortField || sortAscending != defaultAscending)
      'sort': sortParam,
    if (page != 1) 'page': '$page',
    if (size != pageSizes.first) 'size': '$size',
    if (includeDeleted) 'includeDeleted': 'true',
    ...debug,
  };

  Map<String, String> toApiParams() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    ...filterParams,
    'sort': sortParam,
    'page': '$page',
    'size': '$size',
    if (includeDeleted) 'includeDeleted': 'true',
    ...debug,
  };

  Uri toUri(String path) => buildUri(path, toUrlParams());

  @override
  bool operator ==(Object other) =>
      other is ListQuery &&
      other.runtimeType == runtimeType &&
      mapEquals(other.toUrlParams(), toUrlParams());

  @override
  int get hashCode => Object.hashAll(
    (toUrlParams().entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => Object.hash(e.key, e.value)),
  );
}

Uri buildUri(String path, Map<String, String> params) {
  if (params.isEmpty) return Uri(path: path);
  final query = params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value).replaceAll('%2C', ',')}',
      )
      .join('&');
  return Uri(path: path, query: query);
}

int parsePage(String? raw) {
  final value = int.tryParse(raw?.trim() ?? '');
  return (value != null && value > 0) ? value : 1;
}

int parsePageSize(String? raw) {
  final value = int.tryParse(raw?.trim() ?? '');
  return pageSizes.contains(value) ? value! : pageSizes.first;
}

bool parseFlag(String? raw) => raw == 'true' || raw == '1';

({String field, bool ascending}) parseSort(
  String? raw, {
  required Set<String> allowed,
  required String fallback,
}) {
  if (raw == null || raw.trim().isEmpty) {
    return (field: fallback, ascending: true);
  }
  final parts = raw.split(',');
  final field = parts.first.trim();
  if (!allowed.contains(field)) return (field: fallback, ascending: true);
  final direction = parts.length > 1 ? parts[1].trim().toLowerCase() : 'asc';
  return (field: field, ascending: direction != 'desc');
}

Map<String, String> parseDebug(Map<String, String> params) {
  final result = <String, String>{};
  final delay = int.tryParse(params['__delay'] ?? '');
  if (delay != null && delay > 0) result['__delay'] = '$delay';
  final failRaw = params['__fail'] ?? '';
  final fail = int.tryParse(failRaw);
  if (fail != null && fail >= 400 && fail < 600) result['__fail'] = '$fail';
  if (failRaw == 'network' || failRaw == 'timeout') {
    result['__fail'] = failRaw;
  }
  return result;
}

const Object unset = _Unset();

class _Unset {
  const _Unset();
}
