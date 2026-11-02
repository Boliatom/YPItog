abstract class CatalogEntity {
  const CatalogEntity();

  String get id;

  DateTime? get deletedAt;

  bool get isDeleted => deletedAt != null;
}
