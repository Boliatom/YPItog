import 'package:flutter/foundation.dart';

import '../models/rec.dart';
import '../models/rec_query.dart';
import '../repositories/record_repository.dart';
import '../schema/schemas.dart';

class ReferenceCache extends ChangeNotifier {
  ReferenceCache({required this.repositories, required this.events}) {
    events.addListener(_onChanged);
  }

  final SalonRepositories repositories;
  final CatalogEvents events;

  final Map<String, List<Rec>> _items = {};
  final Map<String, Future<List<Rec>>> _loading = {};
  bool _disposed = false;

  List<Rec> cached(String collection) => _items[collection] ?? const [];

  bool has(String collection) => _items.containsKey(collection);

  Future<List<Rec>> load(String collection) {
    final ready = _items[collection];
    if (ready != null) return Future.value(ready);
    return _loading[collection] ??= _fetch(collection);
  }

  Future<List<Rec>> _fetch(String collection) async {
    final schema = schemaFor(collection);
    final result = <Rec>[];
    var page = 1;
    while (true) {
      final chunk = await repositories
          .of(collection)
          .find(RecQuery(schema: schema, page: page, size: 50));
      result.addAll(chunk.items);
      if (!chunk.hasNext || page >= 20) break;
      page++;
    }
    if (!_disposed) {
      _items[collection] = result;
      notifyListeners();
    }
    _loading.remove(collection);
    return result;
  }

  String nameOf(String collection, String id) {
    for (final rec in cached(collection)) {
      if (rec.id == id) return titleOf(rec);
    }
    return '';
  }

  void _onChanged() {
    final section = events.lastSection;
    if (section == null) return;
    _items.remove(section);
    _loading.remove(section);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    events.removeListener(_onChanged);
    super.dispose();
  }
}
