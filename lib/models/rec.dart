import 'catalog_entity.dart';

class Rec extends CatalogEntity {
  const Rec({
    required this.collection,
    required this.id,
    this.values = const {},
    this.labels = const {},
    this.created,
    this.updated,
  });

  final String collection;

  @override
  final String id;

  final Map<String, Object?> values;

  final Map<String, List<String>> labels;
  final DateTime? created;
  final DateTime? updated;

  Object? operator [](String key) => values[key];

  String text(String key) {
    final value = values[key];
    return value == null ? '' : '$value';
  }

  int? integer(String key) {
    final value = values[key];
    if (value is int) return value;
    if (value is num) return value.round();
    return null;
  }

  num? number(String key) {
    final value = values[key];
    return value is num ? value : null;
  }

  bool flag(String key) => values[key] == true;

  DateTime? date(String key) {
    final value = values[key];
    return value is DateTime ? value : null;
  }

  String ref(String key) {
    final value = values[key];
    return value is String ? value : '';
  }

  List<String> refs(String key) {
    final value = values[key];
    return value is List ? [for (final v in value) '$v'] : const [];
  }

  String labelOf(String key) {
    final list = labels[key];
    return (list == null || list.isEmpty) ? '' : list.join(', ');
  }

  @override
  DateTime? get deletedAt => date('deletedAt');

  Rec copyWith({
    Map<String, Object?>? values,
    Map<String, List<String>>? labels,
  }) => Rec(
    collection: collection,
    id: id,
    values: values ?? this.values,
    labels: labels ?? this.labels,
    created: created,
    updated: updated,
  );

  @override
  bool operator ==(Object other) =>
      other is Rec &&
      other.collection == collection &&
      other.id == id &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(collection, id, updated);
}
