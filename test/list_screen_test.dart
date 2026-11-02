import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_support.dart';

String currentUri(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  return GoRouter.of(context).state.uri.toString();
}

Finder keyStartingWith(String prefix) => find.byWidgetPredicate(
  (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith(prefix),
);

void main() {
  testWidgets('список услуг: таблица, всего записей и страницы', (
    tester,
  ) async {
    await pumpAdmin(tester, location: '/services');
    expect(find.text('Услуги'), findsWidgets);
    expect(keyed('total-count'), findsOneWidget);
    expect(find.text('Всего записей: 18'), findsOneWidget);
    expect(find.text('Страница 1 из 2'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('поиск попадает в адрес и сужает список', (tester) async {
    await pumpAdmin(tester, location: '/services');
    await tester.enterText(
      find.descendant(
        of: keyed('filter-search'),
        matching: find.byType(TextField),
      ),
      'массаж',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(currentUri(tester), contains('search='));
    expect(find.text('Всего записей: 3'), findsOneWidget);
  });

  testWidgets('ссылка с условиями отбора открывает отфильтрованный список', (
    tester,
  ) async {
    await pumpAdmin(
      tester,
      location: '/services?priceFrom=3000&priceTo=4500&sort=price,desc',
    );
    expect(find.text('Всего записей: 6'), findsOneWidget);
    expect(currentUri(tester), contains('sort=price,desc'));
  });

  testWidgets('пустой результат не похож на загрузку или ошибку', (
    tester,
  ) async {
    await pumpAdmin(tester, location: '/services?search=zzzzzz');
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(keyed('loading-indicator'), findsNothing);
    expect(find.text('Сбросить фильтры'), findsOneWidget);
  });

  testWidgets('ошибка загрузки с кнопкой повтора', (tester) async {
    await pumpAdmin(tester, location: '/services?__fail=500');
    expect(find.text('Не удалось загрузить данные'), findsOneWidget);
    expect(find.text('Ошибка на сервере. Попробуйте позже.'), findsOneWidget);
    expect(find.text('Повторить'), findsWidgets);
  });

  testWidgets('состояние загрузки показывает индикатор', (tester) async {
    await pumpAdmin(tester, location: '/services?__delay=3000');
    expect(keyed('loading-indicator'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(keyed('loading-indicator'), findsNothing);
  });

  testWidgets('на узком экране вместо таблицы карточки', (tester) async {
    await pumpAdmin(tester, location: '/services', size: const Size(390, 800));
    expect(find.byType(DataTable), findsNothing);
    expect(keyStartingWith('card-'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'логическое удаление скрывает запись, восстановление возвращает',
    (tester) async {
      await pumpAdmin(tester, location: '/services');
      await tester.tap(keyStartingWith('delete-').first);
      await settle(tester);
      await tester.tap(keyed('confirm-ok'));
      await settle(tester, frames: 20);
      expect(find.text('Всего записей: 17'), findsOneWidget);

      await tester.tap(keyed('filter-deleted'));
      await settle(tester, frames: 20);
      expect(find.text('Всего записей: 18'), findsOneWidget);
      expect(keyStartingWith('restore-'), findsOneWidget);
      await tester.tap(keyStartingWith('restore-').first);
      await settle(tester, frames: 20);
      expect(keyStartingWith('restore-'), findsNothing);
    },
  );

  testWidgets('множественное удаление выбранных записей', (tester) async {
    await pumpAdmin(tester, location: '/services');
    final boxes = find.byType(Checkbox);
    await tester.tap(boxes.at(1));
    await tester.tap(boxes.at(2));
    await settle(tester);
    expect(find.text('Выбрано: 2'), findsOneWidget);
    await tester.tap(keyed('delete-selected'));
    await settle(tester);
    await tester.tap(keyed('confirm-ok'));
    await settle(tester, frames: 20);
    expect(find.text('Всего записей: 16'), findsOneWidget);
  });

  testWidgets('постраничный вывод переключает страницу', (tester) async {
    await pumpAdmin(tester, location: '/services');
    await tester.tap(keyed('page-next'));
    await settle(tester, frames: 20);
    expect(currentUri(tester), contains('page=2'));
    expect(find.text('Страница 2 из 2'), findsOneWidget);
  });
}
