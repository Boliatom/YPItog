class TimeRange {
  const TimeRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool overlaps(TimeRange other) =>
      start.isBefore(other.end) && other.start.isBefore(end);
}

class Shift {
  const Shift(this.startTime, this.endTime);

  final String startTime;
  final String endTime;

  static int minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  TimeRange on(DateTime day) {
    final base = DateTime(day.year, day.month, day.day);
    return TimeRange(
      base.add(Duration(minutes: minutes(startTime))),
      base.add(Duration(minutes: minutes(endTime))),
    );
  }
}

const slotStepMinutes = 30;

DateTime endOf(DateTime start, int durationMin) =>
    start.add(Duration(minutes: durationMin));

int discountedPrice(num sum, int discountPercent) {
  final percent = discountPercent.clamp(0, 100);
  return (sum * (100 - percent) / 100).round();
}

List<DateTime> freeSlots({
  required DateTime day,
  required Shift? shift,
  required int durationMin,
  required List<TimeRange> busy,
  DateTime? now,
  int stepMinutes = slotStepMinutes,
}) {
  if (shift == null || durationMin <= 0) return const [];
  final work = shift.on(day);
  final earliest = now ?? DateTime.fromMillisecondsSinceEpoch(0);
  final slots = <DateTime>[];
  var cursor = work.start;
  while (!endOf(cursor, durationMin).isAfter(work.end)) {
    final candidate = TimeRange(cursor, endOf(cursor, durationMin));
    final inFuture = cursor.isAfter(earliest);
    if (inFuture && !busy.any(candidate.overlaps)) slots.add(cursor);
    cursor = cursor.add(Duration(minutes: stepMinutes));
  }
  return slots;
}

String? checkBooking({
  required TimeRange wanted,
  required Shift? shift,
  required List<TimeRange> busy,
}) {
  if (shift == null) return 'Мастер не работает в этот день.';
  final work = shift.on(wanted.start);
  if (wanted.start.isBefore(work.start) || wanted.end.isAfter(work.end)) {
    return 'Время записи выходит за рабочую смену мастера '
        '(${shift.startTime}–${shift.endTime}).';
  }
  if (busy.any(wanted.overlaps)) {
    return 'Это время у мастера уже занято. Выберите другое время.';
  }
  return null;
}
