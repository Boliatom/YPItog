import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salon_app/auth/auth_config.dart';
import 'package:salon_app/repositories/auth_api.dart';
import 'package:salon_app/repositories/local_database.dart';
import 'package:salon_app/repositories/seed_data.dart';
import 'package:salon_app/state/auth_notifier.dart';

void main() {
  late LocalDatabase db;
  late SharedPreferences prefs;
  late DateTime now;

  AuthNotifier make({AuthConfig config = const AuthConfig()}) => AuthNotifier(
    enabled: true,
    config: config,
    prefs: prefs,
    clock: () => now,
    api: LocalAuthApi(db, lifetime: const Duration(seconds: 30)),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = LocalDatabase.seeded(now: DateTime(2026, 11, 2, 12));
    now = DateTime(2026, 11, 2, 12);
  });

  test('вход сохраняет сессию, роль берётся из ответа сервера', () async {
    final auth = make();
    await auth.login(demoMasterEmail, demoMasterPassword);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.role?.apiName, 'master');
    expect(auth.user?.masterId, 'mst000000000001');
    auth.dispose();
  });

  test('токен обновляется до окончания срока', () async {
    final auth = make();
    await auth.login(demoClientEmail, demoClientPassword);
    final first = auth.accessToken;
    now = now.add(const Duration(seconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 3));
    expect(await auth.refreshTokens(), isTrue);
    expect(auth.accessToken, isNot(first));
    expect(auth.isAuthenticated, isTrue);
    auth.dispose();
  });

  test('если обновить токен нельзя, сеанс завершается с сообщением', () async {
    final auth = make();
    await auth.login(demoClientEmail, demoClientPassword);
    db.table('users').removeWhere((u) => u['email'] == demoClientEmail);
    expect(await auth.refreshTokens(), isFalse);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.notice, 'Сеанс истёк. Войдите снова.');
    auth.dispose();
  });

  test('сессия переживает перезагрузку страницы', () async {
    final first = make();
    await first.login(demoAdminEmail, demoAdminPassword);
    now = now.add(const Duration(seconds: 5));
    final second = make();
    await second.restore();
    expect(second.isAuthenticated, isTrue);
    expect(second.user?.email, demoAdminEmail);
    first.dispose();
    second.dispose();
  });

  test('после длительного бездействия сессия не восстанавливается', () async {
    const config = AuthConfig(
      inactivityTimeout: Duration(seconds: 60),
      warningLead: Duration(seconds: 10),
    );
    final first = make(config: config);
    await first.login(demoAdminEmail, demoAdminPassword);
    now = now.add(const Duration(seconds: 90));
    final second = make(config: config);
    await second.restore();
    expect(second.isAuthenticated, isFalse);
    expect(second.notice, contains('нет действий'));
    first.dispose();
    second.dispose();
  });

  test('предельная длительность сессии ограничена', () async {
    const config = AuthConfig(maxSession: Duration(minutes: 5));
    final first = make(config: config);
    await first.login(demoAdminEmail, demoAdminPassword);
    now = now.add(const Duration(minutes: 6));
    final second = make(config: config);
    await second.restore();
    expect(second.isAuthenticated, isFalse);
    expect(second.notice, contains('предельная длительность'));
    first.dispose();
    second.dispose();
  });
}
