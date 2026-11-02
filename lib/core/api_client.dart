import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';

const _retried = 'retried';

bool _mayRefresh(RequestOptions options) =>
    options.headers.containsKey('Authorization') &&
    options.extra[_retried] != true &&
    !options.path.contains('auth-');

Dio buildDio({
  String? baseUrl,
  String? Function()? tokenProvider,
  Future<bool> Function()? refreshSession,
  void Function()? onForbidden,
  void Function()? onNetworkFailure,
  void Function()? onNetworkSuccess,
  bool logRequests = kDebugMode,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) {
          options.headers['Authorization'] = token;
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        onNetworkSuccess?.call();
        if (logRequests) {
          debugPrint(
            '[API] ${response.requestOptions.method} '
            '${response.requestOptions.uri} → ${response.statusCode}',
          );
        }

        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        final alreadyLogged = error.error is ApiException;
        if (logRequests &&
            !alreadyLogged &&
            error.type != DioExceptionType.cancel) {
          final code = error.response?.statusCode;
          debugPrint(
            '[API] ${error.requestOptions.method} ${error.requestOptions.uri} '
            '→ ${code ?? 'сбой ${error.type.name}'}',
          );
        }

        final status = error.response?.statusCode;
        if (error.response != null) {
          onNetworkSuccess?.call();
        } else if (error.type != DioExceptionType.cancel) {
          onNetworkFailure?.call();
        }
        if (status == 403) onForbidden?.call();

        if (status == 401 &&
            refreshSession != null &&
            _mayRefresh(error.requestOptions)) {
          final options = error.requestOptions;
          final current = tokenProvider?.call();
          final renewed =
              (current != null &&
                  options.headers['Authorization'] != current) ||
              await refreshSession();
          if (renewed) {
            try {
              final response = await dio.fetch<dynamic>(
                options.copyWith(extra: {...options.extra, _retried: true}),
              );
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}
