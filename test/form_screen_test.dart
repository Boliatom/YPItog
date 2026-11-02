import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/models/rec_query.dart';
import 'package:salon_app/schema/schemas.dart';

import 'test_support.dart';

Future<void> selectCategory(WidgetTester tester) async {
  await tester.tap(keyed('field-category'));
  await settle(tester);
  await tester.tap(find.text('Парикмахерские услуги').last);
  await settle(tester);
}

Future<void> fill(
  WidgetTester tester, {
  String name = 'Тестовая услуга',
  String duration = '40',
  String price = '900',
}) async {
  await tester.enterText(keyed('field-name'), name);
  await tester.enterText(keyed('field-durationMin'), duration);
  await tester.enterText(keyed('field-price'), price);
  await selectCategory(tester);
}

void main() {
  testWidgets('пустая форма: ошибки у обязательных полей', (tester) async {
    await pumpAdmin(tester, location: '/services/new');
    await tester.ensureVisible(keyed('form-save'));
    await tester.tap(keyed('form-save'));
    await settle(tester);
    expect(find.text('Обязательное поле'), findsWidgets);
    expect(find.text('Выберите значение'), findsOneWidget);
    expect(find.text('Введите число'), findsNWidgets(2));
  });

  testWidgets('числа проверяются по диапазону', (tester) async {
    await pumpAdmin(tester, location: '/services/new');
    await fill(tester, duration: '2', price: '999999');
    await tester.ensureVisible(keyed('form-save'));
    await tester.tap(keyed('form-save'));
    await settle(tester);
    expect(find.text('От 5 до 480'), findsOneWidget);
    expect(find.text('От 1 до 100000'), findsOneWidget);
  });

  testWidgets('ошибка сервера показывается у поля', (tester) async {
    await pumpAdmin(tester, location: '/services/new');
    await fill(tester, name: 'Женская стрижка');
    await tester.ensureVisible(keyed('form-save'));
    await tester.tap(keyed('form-save'));
    await settle(tester, frames: 20);
    expect(find.text('Такое значение уже используется'), findsOneWidget);
    expect(keyed('form-banner'), findsOneWidget);
  });

  testWidgets('корректная услуга сохраняется и появляется в списке', (
    tester,
  ) async {
    final env = await pumpAdmin(tester, location: '/services/new');
    await fill(tester);
    await tester.ensureVisible(keyed('form-save'));
    await tester.tap(keyed('form-save'));
    await settle(tester, frames: 25);
    expect(find.text('Запись создана'), findsOneWidget);
    final page = await env.repositories.services.find(
      RecQuery(schema: servicesSchema, search: 'Тестовая услуга'),
    );
    expect(page.total, 1);
  });

  testWidgets('форма изменения открывается с данными записи', (tester) async {
    await pumpAdmin(tester, location: '/services/srv000000000001/edit');
    expect(find.text('Женская стрижка'), findsOneWidget);
    expect(find.text('Изменение: услуга'), findsOneWidget);
  });

  testWidgets('несуществующая запись: сообщение вместо формы', (tester) async {
    await pumpAdmin(tester, location: '/services/nonexistent01/edit');
    expect(find.text('Запись не найдена.'), findsOneWidget);
  });

  testWidgets('клиенту форма изменения недоступна', (tester) async {
    await pumpAs(
      tester,
      'client@salon.ru',
      'Client2026!',
      location: '/services/new',
    );
    expect(find.text('403 — доступ запрещён'), findsOneWidget);
  });
}
