import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/repositories/seed_data.dart';

import 'test_support.dart';

const widths = [360.0, 768.0, 1280.0, 1920.0];

void main() {
  for (final width in widths) {
    testWidgets(
      'администратор: разделы без переполнения при ${width.toInt()} px',
      (tester) async {
        final size = Size(width, 900);
        await pumpAdmin(tester, location: '/', size: size);
        for (final path in [
          '/',
          '/services',
          '/appointments',
          '/masters',
          '/clients',
          '/services/new',
          '/admin/stats',
          '/admin/users',
        ]) {
          await goTo(tester, path);
          expect(tester.takeException(), isNull, reason: 'раздел $path');
        }
      },
    );
  }

  testWidgets('клиент: запись на узком экране без переполнения', (
    tester,
  ) async {
    await pumpAs(
      tester,
      demoClientEmail,
      demoClientPassword,
      location: '/book',
      size: const Size(360, 900),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Запись на услугу'), findsWidgets);
  });

  testWidgets('навигация: сверху на широком, снизу на телефоне', (
    tester,
  ) async {
    await pumpAdmin(tester, size: const Size(1280, 900));
    expect(find.byKey(const ValueKey('main-nav')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await pumpAdmin(tester, size: const Size(390, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
