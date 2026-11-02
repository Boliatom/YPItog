import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../core/request_token.dart';
import '../core/retry.dart';
import '../models/json_values.dart';
import '../models/page_result.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../schema/entity_schema.dart';
import '../schema/field_def.dart';
import '../schema/schemas.dart';
import 'record_repository.dart';

String _quote(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

String _two(int n) => n.toString().padLeft(2, '0');

String pbDateTime(DateTime moment) {
  final u = moment.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${_two(u.month)}-${_two(u.day)} '
      '${_two(u.hour)}:${_two(u.minute)}:${_two(u.second)}.'
      '${u.millisecond.toString().padLeft(3, '0')}Z';
}

String buildPocketBaseFilter(RecQuery query) {
  final schema = query.schema;
  final parts = <String>[];
  if (!query.includeDeleted) parts.add('deletedAt = ""');
  final search = query.search.trim();
  if (search.isNotEmpty && schema.searchFields.isNotEmpty) {
    final terms = [
      for (final field in schema.searchFields) '$field ~ ${_quote(search)}',
    ];
    parts.add('(${terms.join(' || ')})');
  }
  for (final def in schema.filters) {
    final value = query.filters[def.param];
    if (value == null || value.isEmpty) continue;
    switch (def.type) {
      case FilterType.refEquals:
      case FilterType.optionEquals:
        parts.add('${def.field} = ${_quote(value)}');
      case FilterType.refContains:
        parts.add('${def.field} ?= ${_quote(value)}');
      case FilterType.numMin:
        parts.add('${def.field} >= $value');
      case FilterType.numMax:
        parts.add('${def.field} <= $value');
      case FilterType.dateFrom:
      case FilterType.dateTo:
        final day = DateTime.parse(value);
        final isDateField = schema.field(def.field)?.kind == FieldKind.date;
        final from = def.type == FilterType.dateFrom;
        final moment = isDateField
            ? (from
                  ? DateTime.utc(day.year, day.month, day.day)
                  : DateTime.utc(day.year, day.month, day.day, 23, 59, 59, 999))
            : (from
                  ? DateTime(day.year, day.month, day.day)
                  : DateTime(day.year, day.month, day.day, 23, 59, 59, 999));
        parts.add(
          '${def.field} ${from ? '>=' : '<='} ${_quote(pbDateTime(moment))}',
        );
    }
  }
  return parts.join(' && ');
}

class PocketBaseRepository implements RecordRepository {
  PocketBaseRepository(
    this._dio,
    this.schema, {
    this.retry = const RetryPolicy(),
  });

  final Dio _dio;
  final RetryPolicy retry;

  @override
  final EntitySchema schema;

  String get _path => '/collections/${schema.collection}/records';

  Map<String, Object?> get _expand => {
    if (schema.expandParam.isNotEmpty) 'expand': schema.expandParam,
  };

  Future<R> _read<R>(Future<R> Function() action) =>
      retry.run(() => guard(action));

  Rec _parse(Object? data) {
    final map = asMap(data);
    if (map == null) {
      throw const ServerException('Сервер вернул ответ в неожиданном формате.');
    }
    return schema.parse(map, schemaFor);
  }

  @override
  Future<PageResult<Rec>> find(RecQuery query, {RequestToken? token}) =>
      _read(() async {
        final filter = buildPocketBaseFilter(query);
        final response = await _dio.get(
          _path,
          queryParameters: {
            'page': query.page,
            'perPage': query.size,
            'sort': '${query.sortAscending ? '' : '-'}${query.sortField}',
            if (filter.isNotEmpty) 'filter': filter,
            ..._expand,
          },
          cancelToken: token?.cancelToken,
        );
        final data = asMap(response.data);
        if (data == null || data['items'] is! List) {
          throw const ServerException(
            'Сервер вернул ответ в неожиданном формате.',
          );
        }
        return PageResult<Rec>(
          items: [for (final item in data['items'] as List) _parse(item)],
          page: asInt(data['page'], 1),
          size: asInt(data['perPage'], query.size),
          total: asInt(data['totalItems']),
        );
      });

  @override
  Future<Rec?> findById(String id) => _read(() async {
    try {
      final response = await _dio.get('$_path/$id', queryParameters: _expand);
      return _parse(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  });

  @override
  Future<Rec> create(Map<String, Object?> values) => guard(() async {
    final response = await _dio.post(
      _path,
      data: schema.toBody(values),
      queryParameters: _expand,
    );
    return _parse(response.data);
  });

  @override
  Future<Rec> update(String id, Map<String, Object?> values) => guard(() async {
    final response = await _dio.patch(
      '$_path/$id',
      data: schema.toBody(values),
      queryParameters: _expand,
    );
    return _parse(response.data);
  });

  @override
  Future<void> softDelete(String id) => guard(() async {
    await _dio.patch(
      '$_path/$id',
      data: {'deletedAt': DateTime.now().toUtc().toIso8601String()},
    );
  });

  @override
  Future<void> restore(String id) => guard(() async {
    await _dio.patch('$_path/$id', data: {'deletedAt': ''});
  });

  @override
  Future<void> hardDelete(String id) => guard(() async {
    await _dio.delete('$_path/$id');
  });

  @override
  Future<int> deleteMany(List<String> ids) async {
    var done = 0;
    for (final id in ids) {
      await softDelete(id);
      done++;
    }
    return done;
  }
}

SalonRepositories createPocketBaseRepositories(Dio dio) => SalonRepositories({
  for (final schema in allSchemas)
    schema.collection: PocketBaseRepository(dio, schema),
});
