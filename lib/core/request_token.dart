import 'package:dio/dio.dart';

class RequestToken {
  RequestToken() : _inner = CancelToken();

  final CancelToken _inner;

  CancelToken get cancelToken => _inner;

  bool get isCancelled => _inner.isCancelled;

  void cancel([String reason = 'Запрос устарел']) {
    if (!_inner.isCancelled) _inner.cancel(reason);
  }
}
