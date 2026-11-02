import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException([super.message = 'Запрос отменён.']);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

const _validationMessages = {
  'validation_required': 'Обязательное поле',
  'validation_is_required': 'Обязательное поле',
  'validation_not_unique': 'Такое значение уже используется',
  'validation_invalid_email': 'Некорректный адрес почты',
  'validation_min_text_constraint': 'Слишком короткое значение',
  'validation_max_text_constraint': 'Слишком длинное значение',
  'validation_min_number_constraint': 'Число меньше допустимого',
  'validation_max_number_constraint': 'Число больше допустимого',
  'validation_invalid_value': 'Недопустимое значение',
  'validation_values_mismatch': 'Значения не совпадают',
  'validation_missing_rel_records': 'Связанная запись не найдена',
  'validation_invalid_or_missing_rel_records': 'Связанная запись не найдена',
};

Map<String, String> _fieldErrors(Object? data) {
  if (data is! Map) return const {};
  final result = <String, String>{};
  data.forEach((key, value) {
    if (value is Map) {
      final code = '${value['code']}';
      result['$key'] =
          _validationMessages[code] ??
          (value['message'] is String
              ? value['message'] as String
              : 'Недопустимое значение');
    } else if (value is String) {
      result['$key'] = value;
    }
  });
  return result;
}

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;
  return switch (status) {
    400 || 422 => ValidationException('Проверьте введённые данные.', {
      ..._fieldErrors(body is Map ? body['data'] : null),
      if (body is Map && body['errors'] is Map)
        ...(body['errors'] as Map).map((k, v) => MapEntry('$k', '$v')),
    }),
    401 => const UnauthorizedException('Требуется вход в систему.'),
    403 => const ForbiddenException('Недостаточно прав для этого действия.'),
    404 => const NotFoundException('Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    _ => ServerException(
      status >= 500
          ? 'Ошибка на сервере. Попробуйте позже.'
          : 'Неизвестная ошибка (код $status).',
    ),
  };
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  final response = e.response;
  if (response != null && response.statusCode != null) {
    return mapHttpError(response.statusCode!, response.data);
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя.',
    ),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
      'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
    ),
    DioExceptionType.cancel => const RequestCancelledException(),
    _ => const ServerException(),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  } on TypeError {
    throw const ServerException('Сервер вернул ответ в неожиданном формате.');
  } on FormatException {
    throw const ServerException('Сервер вернул ответ в неожиданном формате.');
  }
}
