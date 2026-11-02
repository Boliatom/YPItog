import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/auth/role.dart';
import 'package:salon_app/models/rec.dart';
import 'package:salon_app/models/rec_query.dart';
import 'package:salon_app/repositories/record_repository.dart';
import 'package:salon_app/repositories/seed_data.dart';
import 'package:salon_app/schema/schemas.dart';

import 'test_support.dart';

Finder keyStartingWith(String prefix) => find.byWidgetPredicate(
  (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(prefix),
);

Future<List<Rec>> appointmentsOf(
  WidgetTester tester,
  SalonRepositories repos, {
  String? status,
}) async {
  final page = await repos.appointments.find(
    RecQuery(
      schema: appointmentsSchema,
      size: 50,
      filters: {'status': ?status},
    ),
  );
  return page.items;
}

void main() {
  testWidgets('главная администратора: показатели салона', (tester) async {
    await pumpAdmin(tester);
    expect(find.text('Записей сегодня'), findsOneWidget);
    expect(find.text('Клиентов'), findsOneWidget);
    expect(find.text('10'), findsWidgets);
    expect(find.text('Услуг в каталоге'), findsOneWidget);
  });

  testWidgets('главная клиента: скидка и бонусы с карты', (tester) async {
    await pumpAs(tester, demoClientEmail, demoClientPassword);
    expect(find.text('Ваша скидка'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
  });

  testWidgets('мои записи: клиент видит только свои', (tester) async {
    final env = await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/my-appointments',
    );
    final own = await env.repositories.appointments.find(
      RecQuery(schema: appointmentsSchema, size: 50),
    );
    expect(
      own.items.every((r) => r.ref('client') == 'cli000000000001'),
      isTrue,
    );
    expect(find.text('Мои записи'), findsWidgets);
    expect(find.text('Всего записей: ${own.total}'), findsOneWidget);
  });

  testWidgets('клиент отменяет будущую запись', (tester) async {
    final env = await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/my-appointments?status=new&sort=startsAt,asc',
    );
    final cancel = keyStartingWith('cancel-');
    expect(cancel, findsWidgets);
    final id = (cancel.first.evaluate().first.widget.key as ValueKey).value
        .toString()
        .substring('cancel-'.length);
    await tester.tap(cancel.first);
    await settle(tester);
    await tester.tap(keyed('confirm-ok'));
    await settle(tester, frames: 25);
    final after = await env.repositories.appointments.findById(id);
    expect(after!.text('status'), 'cancelled');
    expect(find.text('Запись отменена'), findsOneWidget);
  });

  testWidgets('отзыв о выполненной записи: один раз', (tester) async {
    final env = await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/my-appointments?status=done&size=50',
      size: const Size(1280, 1600),
    );
    final reviewed = (await env.repositories.reviews.find(
      RecQuery(schema: reviewsSchema, size: 50),
    )).items.map((r) => r.ref('appointment')).toSet();
    final done = await appointmentsOf(tester, env.repositories, status: 'done');
    final target = done.firstWhere((r) => !reviewed.contains(r.id));

    await tester.ensureVisible(keyed('review-${target.id}'));
    await tester.tap(keyed('review-${target.id}'));
    await settle(tester);
    await tester.tap(keyed('rating-4'));
    await tester.enterText(keyed('review-text'), 'Очень понравилось');
    await tester.tap(keyed('review-submit'));
    await settle(tester, frames: 25);
    expect(find.text('Спасибо за отзыв!'), findsOneWidget);

    await tester.tap(keyed('review-${target.id}'));
    await settle(tester);
    await tester.tap(keyed('review-submit'));
    await settle(tester, frames: 25);
    expect(keyed('review-error'), findsOneWidget);
    expect(find.text('Отзыв об этой записи уже оставлен.'), findsOneWidget);
  });

  testWidgets('мастер меняет статус своей записи', (tester) async {
    final env = await pumpAs(
      tester,
      demoMasterEmail,
      demoMasterPassword,
      location: '/my-schedule?status=new&sort=startsAt,asc',
    );
    final own = await appointmentsOf(tester, env.repositories);
    expect(own.every((r) => r.ref('master') == 'mst000000000001'), isTrue);
    final confirm = keyStartingWith('confirm-');
    expect(confirm, findsWidgets);
    final id = (confirm.first.evaluate().first.widget.key as ValueKey).value
        .toString()
        .substring('confirm-'.length);
    await tester.tap(confirm.first);
    await settle(tester, frames: 25);
    expect(find.text('Запись подтверждена'), findsOneWidget);
    final changed = await env.repositories.appointments.findById(id);
    expect(changed!.text('status'), 'confirmed');
  });

  testWidgets('отчёт: выручка считается по выполненным записям', (
    tester,
  ) async {
    await pumpAdmin(tester, location: '/admin/stats');
    expect(find.text('Выполнено записей'), findsOneWidget);
    expect(find.text('Выручка'), findsOneWidget);
    expect(keyed('stats-masters'), findsOneWidget);
    expect(keyed('stats-services'), findsOneWidget);
  });

  testWidgets('пользователи: администратор меняет роль', (tester) async {
    final env = await pumpAdmin(tester, location: '/admin/users');
    expect(find.text('master@salon.ru'), findsOneWidget);
    await tester.tap(keyed('role-usr000000000003'));
    await settle(tester);
    await tester.tap(find.text('мастер').last);
    await settle(tester, frames: 20);
    final page = await env.users.find();
    final changed = page.items.firstWhere((u) => u.id == 'usr000000000003');
    expect(changed.role.apiName, 'master');
  });

  testWidgets('собственную роль менять нельзя', (tester) async {
    await pumpAdmin(tester, location: '/admin/users');
    final own = tester.widget<DropdownButton<Role>>(
      keyed('role-usr000000000001'),
    );
    expect(own.onChanged, isNull);
    final other = tester.widget<DropdownButton<Role>>(
      keyed('role-usr000000000003'),
    );
    expect(other.onChanged, isNotNull);
  });
}
