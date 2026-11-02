import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ConnectionMonitor extends ChangeNotifier {
  ConnectionMonitor({
    this.probe,
    this.delays = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
    this.restoredNoticeFor = const Duration(seconds: 4),
  });

  ConnectionMonitor.disabled() : this();

  final Future<bool> Function()? probe;
  final List<Duration> delays;
  final Duration restoredNoticeFor;

  bool _online = true;
  bool _recentlyRestored = false;
  bool _checking = false;
  bool _disposed = false;
  int _attempt = 0;
  int _reconnects = 0;
  Timer? _retryTimer;
  Timer? _noticeTimer;

  bool get isOnline => _online;

  bool get recentlyRestored => _recentlyRestored;

  bool get isChecking => _checking;

  int get reconnects => _reconnects;

  void reportFailure() {
    if (_disposed || !_online || probe == null) return;
    _online = false;
    _recentlyRestored = false;
    _noticeTimer?.cancel();
    _attempt = 0;
    notifyListeners();
    _scheduleProbe();
  }

  void reportSuccess() {
    if (_disposed || _online) return;
    _restore();
  }

  Future<void> checkNow() async {
    if (_disposed || _online || _checking) return;
    _retryTimer?.cancel();
    await _runProbe();
  }

  void _scheduleProbe() {
    _retryTimer?.cancel();
    final delay =
        delays[_attempt < delays.length ? _attempt : delays.length - 1];
    _retryTimer = Timer(delay, _runProbe);
  }

  Future<void> _runProbe() async {
    final check = probe;
    if (_disposed || _online || check == null) return;
    _checking = true;
    notifyListeners();
    var ok = false;
    try {
      ok = await check();
    } catch (_) {
      ok = false;
    }
    if (_disposed) return;
    _checking = false;
    if (ok) {
      _restore();
    } else {
      _attempt++;
      notifyListeners();
      _scheduleProbe();
    }
  }

  void _restore() {
    _retryTimer?.cancel();
    _online = true;
    _checking = false;
    _reconnects++;
    _recentlyRestored = true;
    notifyListeners();
    _noticeTimer?.cancel();
    _noticeTimer = Timer(restoredNoticeFor, () {
      if (_disposed) return;
      _recentlyRestored = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}

Future<bool> Function() httpProbe(Dio dio, String path) => () async {
  try {
    await dio.get<dynamic>(
      path,
      options: Options(validateStatus: (_) => true, headers: {'Accept': '*/*'}),
    );
    return true;
  } on DioException catch (e) {
    return e.response != null;
  }
};
