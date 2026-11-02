import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../domain/booking_rules.dart';
import '../models/json_values.dart';
import 'local_database.dart';
import 'pocketbase_repository.dart';

abstract interface class Availability {
  Future<List<TimeRange>> busyRanges(String masterId, DateTime day);
}

class PocketBaseAvailability implements Availability {
  PocketBaseAvailability(this._dio);

  final Dio _dio;

  @override
  Future<List<TimeRange>> busyRanges(String masterId, DateTime day) =>
      guard(() async {
        final from = DateTime(day.year, day.month, day.day);
        final to = from.add(const Duration(days: 1));
        final filter =
            'master = "$masterId" && startsAt >= "${pbDateTime(from)}" '
            '&& startsAt < "${pbDateTime(to)}"';
        final response = await _dio.get(
          '/collections/busy_slots/records',
          queryParameters: {'perPage': 200, 'filter': filter},
        );
        final data = asMap(response.data);
        return [
          for (final item in asMapList(data?['items']))
            if (asDate(item['startsAt']) != null &&
                asDate(item['endsAt']) != null)
              TimeRange(
                asDate(item['startsAt'])!.toLocal(),
                asDate(item['endsAt'])!.toLocal(),
              ),
        ];
      });
}

class LocalAvailability implements Availability {
  LocalAvailability(this._db);

  final LocalDatabase _db;

  @override
  Future<List<TimeRange>> busyRanges(String masterId, DateTime day) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    final result = <TimeRange>[];
    for (final r in _db.table('appointments')) {
      if (r['master'] != masterId ||
          r['status'] == 'cancelled' ||
          '${r['deletedAt'] ?? ''}'.isNotEmpty) {
        continue;
      }
      final start = asDate(r['startsAt'])!.toLocal();
      final end = asDate(r['endsAt'])!.toLocal();
      if (!start.isBefore(from) && start.isBefore(to)) {
        result.add(TimeRange(start, end));
      }
    }
    return result;
  }
}
