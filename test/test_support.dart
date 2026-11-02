import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salon_app/app.dart';
import 'package:salon_app/app_environment.dart';
import 'package:salon_app/core/config.dart';
import 'package:salon_app/repositories/seed_data.dart';
import 'package:salon_app/router.dart';

final DateTime fixedNow = DateTime(2026, 11, 2, 12);

Future<AppEnvironment> createEnvironment(WidgetTester tester) async {
  await tester.runAsync(loadDeferredLibraries);
  final env = await tester.runAsync(
    () => AppEnvironment.create(
      backend: DataBackend.memory,
      usePreferences: false,
    ),
  );
  return env!;
}

Future<void> loginAs(
  WidgetTester tester,
  AppEnvironment env,
  String email,
  String password,
) async {
  await tester.runAsync(() => env.auth.login(email, password));
}

Future<AppEnvironment> pumpApp(
  WidgetTester tester, {
  String? location,
  Size size = const Size(1280, 900),
  String? email,
  String? password,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final env = await createEnvironment(tester);
  if (email != null) await loginAs(tester, env, email, password!);
  await tester.pumpWidget(
    SalonProviders(
      environment: env,
      child: SalonApp(initialLocation: location),
    ),
  );
  await settle(tester);
  return env;
}

Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 80; i++) {
    if (find.text('Загружаем раздел…').evaluate().isEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppEnvironment> pumpAs(
  WidgetTester tester,
  String email,
  String password, {
  String? location,
  Size size = const Size(1280, 900),
}) => pumpApp(
  tester,
  location: location,
  size: size,
  email: email,
  password: password,
);

Future<AppEnvironment> pumpAdmin(
  WidgetTester tester, {
  String? location,
  Size size = const Size(1280, 900),
}) => pumpAs(
  tester,
  demoAdminEmail,
  demoAdminPassword,
  location: location,
  size: size,
);

Finder keyed(String key) => find.byKey(ValueKey(key));

Future<void> goTo(WidgetTester tester, String path) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(path);
  await settle(tester, frames: 8);
}
