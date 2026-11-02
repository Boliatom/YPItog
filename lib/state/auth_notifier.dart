import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_user.dart';
import '../auth/auth_config.dart';
import '../auth/permission.dart';
import '../auth/role.dart';
import '../core/api_exceptions.dart';
import '../repositories/auth_api.dart';

enum SessionEnd { expired, inactivity, maxDuration }

class _Session {
  const _Session({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.startedAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  final DateTime startedAt;
  final AppUser user;
}

class AuthNotifier extends ChangeNotifier {
  AuthNotifier({
    required this.enabled,
    this.config = const AuthConfig(),
    SharedPreferences? prefs,
    DateTime Function()? clock,
    AuthApi? api,
  }) : _prefs = prefs,
       _clock = clock ?? DateTime.now,
       _api = api;

  static const storageKey = 'auth.session';

  static const _persistInterval = Duration(seconds: 5);
  static const _tick = Duration(seconds: 1);
  static const _longestTimer = Duration(days: 1);

  final bool enabled;
  final AuthConfig config;
  final SharedPreferences? _prefs;
  final DateTime Function() _clock;
  AuthApi? _api;

  _Session? _session;
  late DateTime _lastActivity;
  DateTime _persistedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _notice;
  bool _returnAddress = true;
  bool _disposed = false;

  Future<bool>? _refreshing;
  Future<void>? _syncing;
  Timer? _inactivityTimer;
  Timer? _maxTimer;
  final _countdown = ValueNotifier<int?>(null);

  void bind(AuthApi api) => _api = api;

  AuthApi get _requireApi =>
      _api ??
      (throw const ServerException(
        'Вход недоступен для этого источника данных.',
      ));

  String? get accessToken => _session?.accessToken;
  AppUser? get user => _session?.user;
  Role? get role => _session?.user.role;
  bool get isAuthenticated => _session != null;

  String? get notice => _notice;

  bool get rememberReturnAddress => _returnAddress;

  ValueListenable<int?> get inactivityCountdown => _countdown;

  bool can(Permission permission) {
    if (!enabled) return false;
    final role = this.role;
    return role != null && roleHas(role, permission);
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    _notify();
  }

  Future<void> restore() async {
    if (!enabled) return;
    final stored = _readStored();
    if (stored == null) return;
    final (session, lastActivity) = stored;
    final now = _clock();

    if (now.difference(session.startedAt) >= config.maxSession) {
      _finish(SessionEnd.maxDuration, session: session);
      return;
    }
    if (now.difference(lastActivity) >= config.inactivityTimeout) {
      _finish(SessionEnd.inactivity, session: session);
      return;
    }

    _session = session;
    _lastActivity = lastActivity;
    _persistedAt = now;
    _scheduleMax();
    _checkInactivity();

    if (!now.isBefore(session.accessExpiresAt)) {
      await refreshTokens();
    }
    _notify();
  }

  Future<void> login(String email, String password) async {
    final tokens = await _requireApi.login(email.trim(), password);
    final now = _clock();
    _session = _sessionFrom(tokens, startedAt: now);
    _lastActivity = now;
    _notice = null;
    _returnAddress = true;
    _persist(force: true);
    _scheduleMax();
    _checkInactivity();
    _notify();
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _requireApi.register(
      email: email.trim(),
      password: password,
      fullName: fullName.trim(),
    );
    await login(email, password);
  }

  Future<void> logout() async {
    final session = _session;
    _returnAddress = false;
    _notice = null;
    _clearLocal();
    _notify();
    if (session != null) await _revoke(session.refreshToken);
  }

  Future<bool> refreshTokens() {
    final running = _refreshing;
    if (running != null) return running;
    final session = _session;
    if (session == null) return Future.value(false);
    final future = _refresh(session).whenComplete(() => _refreshing = null);
    return _refreshing = future;
  }

  Future<bool> _refresh(_Session before) async {
    if (await _adoptFromOtherTab(before)) return true;
    try {
      final tokens = await _requireApi.refresh(before.refreshToken);
      if (_session == null || _disposed) return false;
      _replace(_sessionFrom(tokens, startedAt: before.startedAt));
      return true;
    } on UnauthorizedException {
      if (_session != null) _finish(SessionEnd.expired);
      return false;
    } on ApiException {
      return false;
    }
  }

  Future<bool> _adoptFromOtherTab(_Session before) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    try {
      await prefs.reload();
    } catch (_) {
      return false;
    }
    final stored = _readStored();
    if (stored == null) return false;
    final session = stored.$1;
    if (session.refreshToken == before.refreshToken) return false;
    if (!_clock().isBefore(session.accessExpiresAt)) return false;
    if (_session == null) return false;
    _replace(session);
    return true;
  }

  Future<void> syncProfile() {
    if (_session == null) return Future.value();
    return _syncing ??= _sync().whenComplete(() => _syncing = null);
  }

  Future<void> _sync() async {
    try {
      final fresh = await _requireApi.me();
      final session = _session;
      if (session == null || _disposed) return;
      if (fresh.role != session.user.role ||
          fresh.fullName != session.user.fullName) {
        _replace(
          _Session(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            accessExpiresAt: session.accessExpiresAt,
            startedAt: session.startedAt,
            user: fresh,
          ),
        );
      }
    } on ApiException {}
  }

  void _replace(_Session next) {
    final previous = _session;
    _session = next;
    _persist(force: true);
    if (previous == null ||
        previous.user.role != next.user.role ||
        previous.user.fullName != next.user.fullName) {
      _notify();
    }
  }

  _Session _sessionFrom(AuthTokens tokens, {required DateTime startedAt}) =>
      _Session(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        accessExpiresAt: _clock().add(tokens.accessLifetime),
        startedAt: startedAt,
        user: tokens.user,
      );

  void recordActivity({bool passive = false}) {
    if (_session == null) return;
    final warning = _countdown.value != null;
    if (warning && passive) return;
    _lastActivity = _clock();
    if (warning) {
      _countdown.value = null;
      _checkInactivity();
    }
    _persist();
  }

  void _checkInactivity() {
    _inactivityTimer?.cancel();
    if (_session == null || _disposed) return;
    final idle = _clock().difference(_lastActivity);
    final left = config.inactivityTimeout - idle;
    if (left <= Duration.zero) {
      _finish(SessionEnd.inactivity);
      return;
    }
    final warnAfter = config.inactivityTimeout - config.warningLead;
    if (idle >= warnAfter) {
      final seconds = (left.inMilliseconds / 1000).ceil();
      if (_countdown.value != seconds) _countdown.value = seconds;
      _inactivityTimer = Timer(left < _tick ? left : _tick, _checkInactivity);
    } else {
      if (_countdown.value != null) _countdown.value = null;
      _inactivityTimer = Timer(warnAfter - idle, _checkInactivity);
    }
  }

  void _scheduleMax() {
    _maxTimer?.cancel();
    final session = _session;
    if (session == null || _disposed) return;
    final left = config.maxSession - _clock().difference(session.startedAt);
    if (left <= Duration.zero) {
      _finish(SessionEnd.maxDuration);
      return;
    }
    _maxTimer = Timer(
      left > _longestTimer ? _longestTimer : left,
      _scheduleMax,
    );
  }

  void _finish(SessionEnd end, {_Session? session}) {
    final ended = session ?? _session;
    _notice = _noticeFor(end);
    _clearLocal();
    _notify();
    if (ended != null) unawaited(_revoke(ended.refreshToken));
  }

  void _clearLocal() {
    _inactivityTimer?.cancel();
    _maxTimer?.cancel();
    _inactivityTimer = null;
    _maxTimer = null;
    _session = null;
    _countdown.value = null;
    unawaited(_prefs?.remove(storageKey));
  }

  Future<void> _revoke(String refreshToken) async {
    try {
      await _api?.logout(refreshToken);
    } catch (_) {}
  }

  String _noticeFor(SessionEnd end) => switch (end) {
    SessionEnd.expired => 'Сеанс истёк. Войдите снова.',
    SessionEnd.inactivity =>
      'Вы вышли из системы: нет действий в течение '
          '${_human(config.inactivityTimeout)}.',
    SessionEnd.maxDuration =>
      'Сеанс завершён: достигнута предельная длительность '
          '(${_human(config.maxSession)}). Войдите снова.',
  };

  static String _human(Duration d) {
    if (d.inSeconds % 3600 == 0 && d.inHours > 0) return '${d.inHours} ч';
    if (d.inSeconds % 60 == 0 && d.inMinutes > 0) return '${d.inMinutes} мин';
    return '${d.inSeconds} с';
  }

  void _persist({bool force = false}) {
    final prefs = _prefs;
    final session = _session;
    if (prefs == null || session == null) return;
    final now = _clock();
    if (!force && now.difference(_persistedAt) < _persistInterval) return;
    _persistedAt = now;
    final json = jsonEncode({
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'accessExpiresAt': session.accessExpiresAt.millisecondsSinceEpoch,
      'startedAt': session.startedAt.millisecondsSinceEpoch,
      'lastActivity': _lastActivity.millisecondsSinceEpoch,
      'user': session.user.toJson(),
    });
    unawaited(prefs.setString(storageKey, json).catchError((_) => false));
  }

  (_Session, DateTime)? _readStored() {
    final prefs = _prefs;
    final raw = prefs?.getString(storageKey);
    if (prefs == null || raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      DateTime time(String key) =>
          DateTime.fromMillisecondsSinceEpoch(json[key] as int);
      final session = _Session(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessExpiresAt: time('accessExpiresAt'),
        startedAt: time('startedAt'),
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      );
      return (session, time('lastActivity'));
    } catch (_) {
      unawaited(prefs.remove(storageKey));
      return null;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _inactivityTimer?.cancel();
    _maxTimer?.cancel();
    _countdown.dispose();
    super.dispose();
  }
}
