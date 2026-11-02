import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../core/request_token.dart';
import '../models/page_result.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../repositories/record_repository.dart';

enum LoadStatus { idle, loading, success, error }

class EntityListNotifier extends ChangeNotifier {
  EntityListNotifier({
    required RecordRepository repository,
    required RecQuery initialQuery,
    CatalogEvents? events,
  }) : _repository = repository,
       _query = initialQuery,
       _events = events {
    _events?.addListener(_onCatalogChanged);
  }

  final RecordRepository _repository;
  final CatalogEvents? _events;

  RecQuery _query;
  PageResult<Rec> _result = PageResult<Rec>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  String? _operationError;
  final Set<String> _selected = {};
  bool _busy = false;
  bool _disposed = false;
  RequestToken? _token;
  int _serial = 0;
  int _loadedRevision = -1;

  RecQuery get query => _query;
  PageResult<Rec> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;
  bool get busy => _busy;
  String? get operationError => _operationError;

  void clearOperationError() {
    _operationError = null;
    _emit();
  }

  Future<void> applyQuery(RecQuery next) async {
    final unchanged =
        next == _query &&
        (_status == LoadStatus.success || _status == LoadStatus.loading);
    if (unchanged) return;
    _query = next;
    _selected.clear();
    await load();
  }

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;
    _token?.cancel();
    final token = _token = RequestToken();
    final serial = ++_serial;
    final query = _query;
    if (!silent || _status != LoadStatus.success) {
      _status = LoadStatus.loading;
      _error = null;
      _emit();
    }
    try {
      final page = await _repository.find(query, token: token);
      if (_disposed || serial != _serial) return;
      if (page.items.isEmpty &&
          page.total > 0 &&
          query.page > page.totalPages) {
        _query = query.withCommon(page: page.totalPages);
        await load(silent: silent);
        return;
      }
      _result = page;
      _loadedRevision = _events?.revision ?? 0;
      _status = LoadStatus.success;
      _selected.removeWhere((id) => !page.items.any((e) => e.id == id));
    } on RequestCancelledException {
      return;
    } on ApiException catch (e) {
      if (_disposed || serial != _serial) return;
      _error = e.message;
      _status = LoadStatus.error;
    } catch (_) {
      if (_disposed || serial != _serial) return;
      _error = 'Не удалось загрузить список. Попробуйте ещё раз.';
      _status = LoadStatus.error;
    }
    _emit();
  }

  bool get isStale => (_events?.revision ?? 0) != _loadedRevision;

  void _onCatalogChanged() {
    if (_status == LoadStatus.idle || _busy) return;
    load(silent: true);
  }

  void toggleSelection(String id) {
    if (_busy || _status != LoadStatus.success) return;
    final item = _result.items.where((e) => e.id == id).firstOrNull;
    if (item == null || item.isDeleted) return;
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _emit();
  }

  void selectAll(bool value) {
    if (_busy || _status != LoadStatus.success) return;
    _selected.clear();
    if (value) {
      _selected.addAll(
        _result.items.where((e) => !e.isDeleted).map((e) => e.id),
      );
    }
    _emit();
  }

  void clearSelection() {
    _selected.clear();
    _emit();
  }

  Future<bool> softDelete(String id) =>
      _mutate(() => _repository.softDelete(id));

  Future<bool> hardDelete(String id) =>
      _mutate(() => _repository.hardDelete(id));

  Future<bool> restore(String id) => _mutate(() => _repository.restore(id));

  Future<bool> update(String id, Map<String, Object?> values) =>
      _mutate(() => _repository.update(id, values));

  Future<bool> deleteSelected() {
    final ids = _selected.toList();
    return _mutate(() => _repository.deleteMany(ids));
  }

  Future<bool> _mutate(Future<Object?> Function() operation) async {
    if (_busy || _disposed) return false;
    _busy = true;
    _operationError = null;
    _emit();
    try {
      await operation();
      if (_disposed) return false;
      _selected.clear();
      _busy = false;
      if (_events == null || isStale) await load();
      return true;
    } on RequestCancelledException {
      return false;
    } on ApiException catch (e) {
      _operationError = e.message;
      return false;
    } catch (_) {
      _operationError = 'Не удалось выполнить действие. Повторите попытку.';
      return false;
    } finally {
      _busy = false;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    _events?.removeListener(_onCatalogChanged);
    super.dispose();
  }
}
