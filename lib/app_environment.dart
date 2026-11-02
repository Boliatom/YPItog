import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_config.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/connection_monitor.dart';
import 'domain/booking_service.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/auth_api.dart';
import 'repositories/availability.dart';
import 'repositories/local_database.dart';
import 'repositories/local_repository.dart';
import 'repositories/pocketbase_repository.dart';
import 'repositories/record_repository.dart';
import 'state/auth_notifier.dart';
import 'state/reference_cache.dart';
import 'state/unsaved_changes_guard.dart';

SalonRepositories withAppointmentRules(SalonRepositories base) {
  final wrapped = AppointmentRepository(
    base.appointments,
    base.services,
    base.cards,
  );
  return SalonRepositories({
    for (final c in base.collections)
      c: c == 'appointments' ? wrapped : base.of(c),
  });
}

class AppEnvironment {
  AppEnvironment({
    required this.backend,
    required this.repositories,
    required this.events,
    required this.auth,
    required this.booking,
    required this.users,
    ConnectionMonitor? connection,
    this.dio,
    this.notice,
  }) : connection = connection ?? ConnectionMonitor.disabled();

  final DataBackend backend;
  final SalonRepositories repositories;
  final CatalogEvents events;
  final AuthNotifier auth;
  final BookingService booking;
  final UserRepository users;
  final ConnectionMonitor connection;
  final Dio? dio;
  final String? notice;

  static Future<AppEnvironment> create({
    DataBackend? backend,
    String? baseUrl,
    AuthConfig authConfig = const AuthConfig(),
    SharedPreferences? preferences,
    bool usePreferences = true,
    Duration localLatency = Duration.zero,
  }) async {
    final chosen = backend ?? DataBackend.parse(backendName);
    final events = CatalogEvents();
    SharedPreferences? prefs = preferences;
    if (prefs == null && usePreferences) {
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}
    }
    final auth = AuthNotifier(enabled: true, config: authConfig, prefs: prefs);

    if (chosen == DataBackend.api) {
      final url = baseUrl ?? apiBaseUrl;
      if (url.isEmpty) {
        auth.dispose();
        throw const MissingApiUrlException();
      }
      final probeDio = Dio(
        BaseOptions(
          baseUrl: url,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final connection = ConnectionMonitor(
        probe: httpProbe(probeDio, apiHealthPath),
      );
      final dio = buildDio(
        baseUrl: url,
        onNetworkFailure: connection.reportFailure,
        onNetworkSuccess: connection.reportSuccess,
        tokenProvider: () => auth.accessToken,
        refreshSession: auth.refreshTokens,
        onForbidden: () => unawaited(auth.syncProfile()),
      );
      final api = PocketBaseAuthApi(dio);
      auth.bind(api);
      await auth.restore();
      final repos = decorate(
        withAppointmentRules(createPocketBaseRepositories(dio)),
        events,
      );
      return AppEnvironment(
        backend: chosen,
        repositories: repos,
        events: events,
        auth: auth,
        booking: BookingService(
          repositories: repos,
          availability: PocketBaseAvailability(dio),
        ),
        users: api,
        connection: connection,
        dio: dio,
      );
    }

    final persistent = chosen == DataBackend.persistent && prefs != null;
    final db = persistent
        ? LocalDatabase.restore(prefs)
        : LocalDatabase.seeded();
    final api = LocalAuthApi(db);
    auth.bind(api);
    await auth.restore();
    final repos = decorate(
      withAppointmentRules(
        createLocalRepositories(db, () => auth.user, latency: localLatency),
      ),
      events,
    );
    return AppEnvironment(
      backend: chosen,
      repositories: repos,
      events: events,
      auth: auth,
      booking: BookingService(
        repositories: repos,
        availability: LocalAvailability(db),
      ),
      users: api,
      notice:
          db.notice ??
          (chosen == DataBackend.persistent && prefs == null
              ? 'Хранилище браузера недоступно: изменения не сохранятся.'
              : null),
    );
  }
}

class SalonProviders extends StatefulWidget {
  const SalonProviders({
    super.key,
    required this.environment,
    required this.child,
  });

  final AppEnvironment environment;
  final Widget child;

  @override
  State<SalonProviders> createState() => _SalonProvidersState();
}

class _SalonProvidersState extends State<SalonProviders> {
  AppEnvironment get environment => widget.environment;

  @override
  void dispose() {
    environment.auth.dispose();
    environment.connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = environment;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CatalogEvents>.value(value: env.events),
        ChangeNotifierProvider<AuthNotifier>.value(value: env.auth),
        ChangeNotifierProvider<ConnectionMonitor>.value(value: env.connection),
        Provider<SalonRepositories>.value(value: env.repositories),
        Provider<BookingService>.value(value: env.booking),
        Provider<UserRepository>.value(value: env.users),
        ChangeNotifierProvider<ReferenceCache>(
          create: (_) => ReferenceCache(
            repositories: env.repositories,
            events: env.events,
          ),
        ),
        Provider<UnsavedChangesGuard>(create: (_) => UnsavedChangesGuard()),
      ],
      child: widget.child,
    );
  }
}
