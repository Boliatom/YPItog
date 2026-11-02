import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/models/rec_query.dart';
import 'package:salon_app/repositories/seed_data.dart';
import 'package:salon_app/schema/schemas.dart';

import 'test_support.dart';

Finder slotChips() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('slot-'),
);

Future<void> chooseDay(WidgetTester tester) async {
  await tester.tap(keyed('booking-day'));
  await settle(tester);
  await tester.tap(find.widgetWithText(TextButton, 'ОК'));
  await settle(tester, frames: 20);
}

Future<void> chooseMaster(WidgetTester tester) async {
  await tester.tap(keyed('booking-master'));
  await settle(tester);
  await tester.tap(find.textContaining('Орлова').last);
  await settle(tester);
}

void main() {
  testWidgets('без услуг мастер и время недоступны', (tester) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/book',
      size: const Size(1280, 2400),
    );
    expect(find.text('Сначала выберите хотя бы одну услугу.'), findsOneWidget);
    final button = tester.widget<FilledButton>(keyed('booking-submit'));
    expect(button.onPressed, isNull);
  });

  testWidgets('мастера подбираются под выбранные услуги', (tester) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/book',
      size: const Size(1280, 2400),
    );
    await tester.tap(keyed('service-srv000000000001'));
    await settle(tester);
    expect(keyed('booking-master'), findsOneWidget);
    await tester.tap(keyed('service-srv000000000006'));
    await settle(tester);
    expect(keyed('no-masters'), findsOneWidget);
  });

  testWidgets('запись: слот, цена со скидкой и сохранение', (tester) async {
    final env = await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/book',
      size: const Size(1280, 2400),
    );
    await tester.tap(keyed('service-srv000000000001'));
    await settle(tester);
    expect(find.text('Итого: 1620 ₽'), findsOneWidget);
    await chooseMaster(tester);
    await chooseDay(tester);
    expect(slotChips(), findsWidgets);

    await tester.tap(slotChips().first);
    await settle(tester);
    await tester.ensureVisible(keyed('booking-submit'));
    await tester.tap(keyed('booking-submit'));
    await settle(tester, frames: 25);

    expect(find.text('Вы записаны. Мы ждём вас!'), findsOneWidget);
    final mine = await env.repositories.appointments.find(
      RecQuery(schema: appointmentsSchema, size: 50),
    );
    final created = mine.items.where(
      (r) =>
          r.ref('master') == 'mst000000000001' &&
          r.integer('discountPercent') == 10 &&
          r.number('totalPrice') == 1620,
    );
    expect(created, isNotEmpty);
  });

  testWidgets('занятое время исчезает из списка слотов после записи', (
    tester,
  ) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/book',
      size: const Size(1280, 2400),
    );
    await tester.tap(keyed('service-srv000000000001'));
    await settle(tester);
    await chooseMaster(tester);
    await chooseDay(tester);
    final before = slotChips().evaluate().length;
    final first = slotChips().first;
    final label = (tester.widget<ChoiceChip>(first).label as Text).data;
    await tester.tap(first);
    await settle(tester);
    await tester.ensureVisible(keyed('booking-submit'));
    await tester.tap(keyed('booking-submit'));
    await settle(tester, frames: 25);

    await tester.tap(keyed('nav-book'));
    await settle(tester, frames: 20);
    await tester.tap(keyed('service-srv000000000001'));
    await settle(tester);
    await chooseMaster(tester);
    await chooseDay(tester);
    expect(slotChips().evaluate().length, lessThan(before));
    expect(find.text(label!), findsNothing);
  });
}
