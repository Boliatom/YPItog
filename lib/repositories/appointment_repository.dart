import '../core/request_token.dart';
import '../domain/booking_rules.dart';
import '../models/page_result.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../schema/entity_schema.dart';
import '../schema/schemas.dart';
import 'record_repository.dart';

class AppointmentRepository implements RecordRepository {
  AppointmentRepository(this._inner, this._services, this._cards);

  final RecordRepository _inner;
  final RecordRepository _services;
  final RecordRepository _cards;

  @override
  EntitySchema get schema => _inner.schema;

  Future<Map<String, Object?>> _prepare(Map<String, Object?> values) async {
    final ids = values['services'];
    final start = values['startsAt'];
    if (ids is! List || ids.isEmpty || start is! DateTime) return values;
    var minutes = 0;
    num sum = 0;
    for (final id in ids) {
      final service = await _services.findById('$id');
      if (service == null) continue;
      minutes += service.integer('durationMin') ?? 0;
      sum += service.number('price') ?? 0;
    }
    var discount = 0;
    final client = values['client'];
    if (client is String && client.isNotEmpty) {
      final cards = await _cards.find(
        RecQuery(schema: cardsSchema, filters: {'client': client}, size: 10),
      );
      discount = cards.items.firstOrNull?.integer('discountPercent') ?? 0;
    }
    return {
      ...values,
      'endsAt': endOf(start, minutes),
      'discountPercent': discount,
      'totalPrice': discountedPrice(sum, discount),
    };
  }

  @override
  Future<PageResult<Rec>> find(RecQuery query, {RequestToken? token}) =>
      _inner.find(query, token: token);

  @override
  Future<Rec?> findById(String id) => _inner.findById(id);

  @override
  Future<Rec> create(Map<String, Object?> values) async =>
      _inner.create(await _prepare(values));

  @override
  Future<Rec> update(String id, Map<String, Object?> values) async {
    final touchesPricing =
        values.containsKey('services') && values.containsKey('startsAt');
    return _inner.update(id, touchesPricing ? await _prepare(values) : values);
  }

  @override
  Future<void> softDelete(String id) => _inner.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _inner.hardDelete(id);

  @override
  Future<void> restore(String id) => _inner.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _inner.deleteMany(ids);
}
