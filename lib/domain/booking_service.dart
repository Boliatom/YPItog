import '../models/rec.dart';
import '../models/rec_query.dart';
import '../repositories/availability.dart';
import '../repositories/record_repository.dart';
import '../schema/schemas.dart';
import 'booking_rules.dart';

class BookingService {
  BookingService({required this.repositories, required this.availability});

  final SalonRepositories repositories;
  final Availability availability;

  Future<Shift?> shiftOf(String masterId, DateTime day) async {
    final page = await repositories.schedules.find(
      RecQuery(
        schema: schedulesSchema,
        filters: {'master': masterId, 'weekday': weekdayKey(day)},
        size: 10,
      ),
    );
    final row = page.items.firstOrNull;
    if (row == null) return null;
    return Shift(row.text('startTime'), row.text('endTime'));
  }

  Future<List<DateTime>> freeSlotsFor({
    required String masterId,
    required DateTime day,
    required int durationMin,
    DateTime? now,
  }) async {
    final shift = await shiftOf(masterId, day);
    if (shift == null) return const [];
    final busy = await availability.busyRanges(masterId, day);
    return freeSlots(
      day: day,
      shift: shift,
      durationMin: durationMin,
      busy: busy,
      now: now ?? DateTime.now(),
    );
  }

  Future<int> discountFor(String clientId) async {
    final cards = await repositories.cards.find(
      RecQuery(schema: cardsSchema, filters: {'client': clientId}, size: 10),
    );
    return cards.items.firstOrNull?.integer('discountPercent') ?? 0;
  }

  Future<Rec> book({
    required String clientId,
    required String masterId,
    required List<String> serviceIds,
    required DateTime startsAt,
    String comment = '',
  }) => repositories.appointments.create({
    'client': clientId,
    'master': masterId,
    'services': serviceIds,
    'startsAt': startsAt,
    'status': 'new',
    'comment': comment,
  });
}
