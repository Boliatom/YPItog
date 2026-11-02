import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salon_app/repositories/seed_data.dart';

import 'test_support.dart';

String location(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).first);
  return GoRouter.of(context).state.uri.toString();
}

void main() {
  testWidgets('без входа открывается форма входа и запоминается адрес', (
    tester,
  ) async {
    await pumpApp(tester, location: '/services');
    expect(find.text('Вход в систему'), findsOneWidget);
    expect(location(tester), startsWith('/login'));
    expect(location(tester), contains('from=%2Fservices'));
  });

  testWidgets('неверный пароль показывает сообщение', (tester) async {
    await pumpApp(tester);
    await tester.enterText(keyed('login-username'), demoAdminEmail);
    await tester.enterText(keyed('login-password'), 'Wrong1234!');
    await tester.tap(keyed('login-submit'));
    await settle(tester);
    expect(find.text('Неверная почта или пароль.'), findsOneWidget);
    expect(find.text('Вход в систему'), findsOneWidget);
  });

  testWidgets('пустые поля не отправляются', (tester) async {
    await pumpApp(tester);
    await tester.tap(keyed('login-submit'));
    await settle(tester);
    expect(find.text('Введите почту'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
  });

  testWidgets('после входа открывается запрошенный раздел', (tester) async {
    await pumpApp(tester, location: '/services');
    await tester.enterText(keyed('login-username'), demoClientEmail);
    await tester.enterText(keyed('login-password'), demoClientPassword);
    await tester.tap(keyed('login-submit'));
    await settle(tester, frames: 20);
    expect(location(tester), '/services');
    expect(find.text('Услуги'), findsWidgets);
  });

  testWidgets('у каждой роли свой набор разделов', (tester) async {
    await pumpAs(tester, demoClientEmail, demoClientPassword);
    expect(keyed('nav-book'), findsOneWidget);
    expect(keyed('nav-my-appointments'), findsOneWidget);
    expect(keyed('nav-appointments'), findsNothing);
    expect(keyed('nav-users'), findsNothing);
    expect(keyed('nav-my-schedule'), findsNothing);
  });

  testWidgets('мастер видит своё расписание, но не запись онлайн', (
    tester,
  ) async {
    await pumpAs(tester, demoMasterEmail, demoMasterPassword);
    expect(keyed('nav-my-schedule'), findsOneWidget);
    expect(keyed('nav-book'), findsNothing);
    expect(keyed('nav-users'), findsNothing);
  });

  testWidgets('администратор видит записи, пользователей и отчёт', (
    tester,
  ) async {
    await pumpAdmin(tester);
    expect(keyed('nav-appointments'), findsOneWidget);
    expect(keyed('nav-users'), findsOneWidget);
    expect(keyed('nav-stats'), findsOneWidget);
    expect(keyed('nav-book'), findsNothing);
  });

  testWidgets('чужой адрес вручную ведёт на экран отказа', (tester) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/admin/users',
    );
    expect(find.text('403 — доступ запрещён'), findsOneWidget);
    expect(location(tester), startsWith('/forbidden'));
  });

  testWidgets('клиенту закрыт список клиентов', (tester) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/clients',
    );
    expect(find.text('403 — доступ запрещён'), findsOneWidget);
  });

  testWidgets('кнопки изменения скрыты у роли без прав', (tester) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/services',
    );
    expect(keyed('create-button'), findsNothing);
    await pumpAdmin(tester, location: '/services');
    expect(keyed('create-button'), findsOneWidget);
  });

  testWidgets('выход возвращает на форму входа', (tester) async {
    final env = await pumpAdmin(tester);
    await tester.tap(keyed('user-menu'));
    await settle(tester);
    await tester.tap(keyed('logout'));
    await settle(tester);
    expect(env.auth.isAuthenticated, isFalse);
    expect(find.text('Вход в систему'), findsOneWidget);
  });
}
