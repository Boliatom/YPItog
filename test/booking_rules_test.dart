import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/domain/booking_rules.dart';

void main() {
  final day = DateTime(2026, 11, 3);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 3, h, m);

  group('freeSlots', () {
    test('исключает занятое время и выход за смену', () {
      final slots = freeSlots(
        day: day,
        shift: const Shift('10:00', '13:00'),
        durationMin: 60,
        busy: [TimeRange(at(11), at(12))],
      );
      expect(slots, [at(10), at(12)]);
    });

    test('не предлагает время в прошлом', () {
      final slots = freeSlots(
        day: day,
        shift: const Shift('10:00', '13:00'),
        durationMin: 60,
        busy: [TimeRange(at(11), at(12))],
        now: at(10, 30),
      );
      expect(slots, [at(12)]);
    });

    test('без смены слотов нет', () {
      expect(
        freeSlots(day: day, shift: null, durationMin: 30, busy: const []),
        isEmpty,
      );
    });

    test('услуга длиннее смены не помещается', () {
      expect(
        freeSlots(
          day: day,
          shift: const Shift('10:00', '11:00'),
          durationMin: 90,
          busy: const [],
        ),
        isEmpty,
      );
    });
  });

  group('checkBooking', () {
    const shift = Shift('10:00', '18:00');

    test('свободное время в смене подходит', () {
      expect(
        checkBooking(
          wanted: TimeRange(at(10), at(11)),
          shift: shift,
          busy: [TimeRange(at(12), at(13))],
        ),
        isNull,
      );
    });

    test('пересечение с другой записью отклоняется', () {
      final message = checkBooking(
        wanted: TimeRange(at(12, 30), at(13, 30)),
        shift: shift,
        busy: [TimeRange(at(12), at(13))],
      );
      expect(message, contains('занято'));
    });

    test('внутри чужой записи и впритык: впритык допустимо', () {
      expect(
        checkBooking(
          wanted: TimeRange(at(13), at(14)),
          shift: shift,
          busy: [TimeRange(at(12), at(13))],
        ),
        isNull,
      );
    });

    test('вне смены и без смены', () {
      expect(
        checkBooking(
          wanted: TimeRange(at(9), at(10)),
          shift: shift,
          busy: const [],
        ),
        contains('рабочую смену'),
      );
      expect(
        checkBooking(
          wanted: TimeRange(at(10), at(11)),
          shift: null,
          busy: const [],
        ),
        contains('не работает'),
      );
    });
  });

  group('расчёт', () {
    test('цена со скидкой округляется', () {
      expect(discountedPrice(1999, 15), 1699);
      expect(discountedPrice(1000, 0), 1000);
      expect(discountedPrice(1000, 100), 0);
    });

    test('окончание записи и разбор времени', () {
      expect(endOf(at(10), 90), at(11, 30));
      expect(Shift.minutes('09:30'), 570);
      expect(Shift.minutes('abc'), 0);
    });
  });
}
