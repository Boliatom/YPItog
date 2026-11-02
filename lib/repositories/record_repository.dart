import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../core/request_token.dart';
import '../models/page_result.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../schema/entity_schema.dart';
import '../schema/schemas.dart';

abstract interface class RecordRepository {
  EntitySchema get schema;

  Future<PageResult<Rec>> find(RecQuery query, {RequestToken? token});

  Future<Rec?> findById(String id);

  Future<Rec> create(Map<String, Object?> values);

  Future<Rec> update(String id, Map<String, Object?> values);

  Future<void> softDelete(String id);

  Future<void> hardDelete(String id);

  Future<void> restore(String id);

  Future<int> deleteMany(List<String> ids);
}

class CatalogEvents extends ChangeNotifier {
  int _revision = 0;
  String? _lastSection;

  int get revision => _revision;
  String? get lastSection => _lastSection;

  void emit(String section) {
    _revision++;
    _lastSection = section;
    notifyListeners();
  }
}

class ObservedRepository implements RecordRepository {
  ObservedRepository(this._inner, this._events);

  final RecordRepository _inner;
  final CatalogEvents _events;

  @override
  EntitySchema get schema => _inner.schema;

  @override
  Future<PageResult<Rec>> find(RecQuery query, {RequestToken? token}) =>
      _inner.find(query, token: token);

  @override
  Future<Rec?> findById(String id) => _inner.findById(id);

  Future<R> _changed<R>(Future<R> Function() action) async {
    final result = await action();
    _events.emit(schema.collection);
    return result;
  }

  @override
  Future<Rec> create(Map<String, Object?> values) =>
      _changed(() => _inner.create(values));

  @override
  Future<Rec> update(String id, Map<String, Object?> values) =>
      _changed(() => _inner.update(id, values));

  @override
  Future<void> softDelete(String id) => _changed(() => _inner.softDelete(id));

  @override
  Future<void> hardDelete(String id) => _changed(() => _inner.hardDelete(id));

  @override
  Future<void> restore(String id) => _changed(() => _inner.restore(id));

  @override
  Future<int> deleteMany(List<String> ids) =>
      _changed(() => _inner.deleteMany(ids));
}

class DebugAwareRepository implements RecordRepository {
  DebugAwareRepository(this._inner);

  final RecordRepository _inner;

  @override
  EntitySchema get schema => _inner.schema;

  @override
  Future<PageResult<Rec>> find(RecQuery query, {RequestToken? token}) async {
    final delay = int.tryParse(query.debug['__delay'] ?? '');
    if (delay != null && delay > 0) {
      await Future<void>.delayed(Duration(milliseconds: delay));
    }
    final failRaw = query.debug['__fail'] ?? '';
    if (failRaw == 'network') throw const NetworkException();
    if (failRaw == 'timeout') {
      throw const NetworkException('Сервер не ответил вовремя.');
    }
    final fail = int.tryParse(failRaw);
    if (fail != null) throw mapHttpError(fail, const {});
    if (token != null && token.isCancelled) {
      throw const RequestCancelledException();
    }
    return _inner.find(query, token: token);
  }

  @override
  Future<Rec?> findById(String id) => _inner.findById(id);

  @override
  Future<Rec> create(Map<String, Object?> values) => _inner.create(values);

  @override
  Future<Rec> update(String id, Map<String, Object?> values) =>
      _inner.update(id, values);

  @override
  Future<void> softDelete(String id) => _inner.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _inner.hardDelete(id);

  @override
  Future<void> restore(String id) => _inner.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _inner.deleteMany(ids);
}

class SalonRepositories {
  SalonRepositories(Map<String, RecordRepository> byCollection)
    : _byCollection = Map.unmodifiable(byCollection);

  final Map<String, RecordRepository> _byCollection;

  RecordRepository of(String collection) {
    final repo = _byCollection[collection];
    if (repo == null) {
      throw ArgumentError('Нет репозитория для $collection');
    }
    return repo;
  }

  RecordRepository get categories => of('service_categories');
  RecordRepository get services => of('services');
  RecordRepository get masters => of('masters');
  RecordRepository get clients => of('clients');
  RecordRepository get cards => of('client_cards');
  RecordRepository get appointments => of('appointments');
  RecordRepository get reviews => of('reviews');
  RecordRepository get schedules => of('schedules');

  SalonRepositories map(RecordRepository Function(RecordRepository) wrap) =>
      SalonRepositories({
        for (final entry in _byCollection.entries) entry.key: wrap(entry.value),
      });

  Iterable<String> get collections => _byCollection.keys;
}

SalonRepositories decorate(SalonRepositories inner, CatalogEvents events) =>
    inner.map((repo) => ObservedRepository(DebugAwareRepository(repo), events));

List<String> get allCollections => [for (final s in allSchemas) s.collection];
