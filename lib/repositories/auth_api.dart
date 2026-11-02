import 'dart:convert';

import 'package:dio/dio.dart';

import '../auth/app_user.dart';
import '../auth/role.dart';
import '../core/api_exceptions.dart';
import '../core/request_token.dart';
import '../models/json_values.dart';
import '../models/page_result.dart';
import 'local_database.dart';
import 'seed_data.dart';

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final Duration accessLifetime;
  final AppUser user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessLifetime,
    required this.user,
  });
}

abstract interface class AuthApi {
  Future<AuthTokens> login(String email, String password);

  Future<AppUser> register({
    required String email,
    required String password,
    required String fullName,
  });

  Future<AuthTokens> refresh(String refreshToken);

  Future<AppUser> me();

  Future<void> logout(String refreshToken);
}

abstract interface class UserRepository {
  Future<PageResult<AppUser>> find({
    int page = 1,
    int size = 10,
    RequestToken? token,
  });

  Future<AppUser> changeRole(String id, Role role);
}

Duration tokenLifetime(String token, {DateTime? now}) {
  try {
    final parts = token.split('.');
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final exp = asInt((jsonDecode(payload) as Map)['exp']);
    final seconds =
        exp - ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000);
    if (seconds > 0) return Duration(seconds: seconds);
  } catch (_) {}
  return const Duration(minutes: 15);
}

class PocketBaseAuthApi implements AuthApi, UserRepository {
  PocketBaseAuthApi(this._dio);

  final Dio _dio;

  static const _users = '/collections/users';

  AuthTokens _tokens(Object? body, {String? fallbackToken}) {
    final data = asMap(body);
    final record = asMap(data?['record']);
    final token = asStringOrNull(data?['token']) ?? fallbackToken;
    if (data == null || record == null || token == null) {
      throw const ServerException('Сервер вернул ответ в неожиданном формате.');
    }
    return AuthTokens(
      accessToken: token,
      refreshToken: token,
      accessLifetime: tokenLifetime(token),
      user: AppUser.fromJson(record),
    );
  }

  @override
  Future<AuthTokens> login(String email, String password) => guard(() async {
    final response = await _dio.post(
      '$_users/auth-with-password',
      data: {'identity': email, 'password': password},
    );
    return _tokens(response.data);
  });

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String fullName,
  }) => guard(() async {
    final response = await _dio.post(
      '$_users/records',
      data: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': fullName,
      },
    );
    final record = asMap(response.data);
    if (record == null) {
      throw const ServerException('Сервер вернул ответ в неожиданном формате.');
    }
    return AppUser.fromJson(record);
  });

  @override
  Future<AuthTokens> refresh(String refreshToken) => guard(() async {
    final response = await _dio.post(
      '$_users/auth-refresh',
      options: Options(headers: {'Authorization': refreshToken}),
    );
    return _tokens(response.data, fallbackToken: refreshToken);
  });

  @override
  Future<AppUser> me() => guard(() async {
    final response = await _dio.post('$_users/auth-refresh');
    return _tokens(response.data).user;
  });

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<PageResult<AppUser>> find({
    int page = 1,
    int size = 10,
    RequestToken? token,
  }) => guard(() async {
    final response = await _dio.get(
      '$_users/records',
      queryParameters: {'page': page, 'perPage': size, 'sort': 'email'},
      cancelToken: token?.cancelToken,
    );
    final data = asMap(response.data);
    if (data == null || data['items'] is! List) {
      throw const ServerException('Сервер вернул ответ в неожиданном формате.');
    }
    return PageResult<AppUser>(
      items: [
        for (final item in asMapList(data['items'])) AppUser.fromJson(item),
      ],
      page: asInt(data['page'], 1),
      size: asInt(data['perPage'], size),
      total: asInt(data['totalItems']),
    );
  });

  @override
  Future<AppUser> changeRole(String id, Role role) => guard(() async {
    final response = await _dio.patch(
      '$_users/records/$id',
      data: {'role': role.apiName},
    );
    final record = asMap(response.data);
    if (record == null) {
      throw const ServerException('Сервер вернул ответ в неожиданном формате.');
    }
    return AppUser.fromJson(record);
  });
}

class LocalAuthApi implements AuthApi, UserRepository {
  LocalAuthApi(this._db, {this.lifetime = const Duration(minutes: 15)});

  final LocalDatabase _db;
  final Duration lifetime;
  String? _currentId;

  AuthTokens _tokensFor(Map<String, Object?> row) {
    _currentId = '${row['id']}';
    return AuthTokens(
      accessToken:
          'local.${row['id']}.${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'local.${row['id']}',
      accessLifetime: lifetime,
      user: AppUser.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  Map<String, Object?>? _row(String id) => _db.find('users', id);

  @override
  Future<AuthTokens> login(String email, String password) async {
    final matches = _db
        .table('users')
        .where(
          (u) => '${u['email']}'.toLowerCase() == email.trim().toLowerCase(),
        );
    if (matches.isEmpty || matches.first['password'] != password) {
      throw const ValidationException('Неверная почта или пароль.', {
        'password': 'Неверная почта или пароль',
      });
    }
    return _tokensFor(matches.first);
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final taken = _db
        .table('users')
        .any(
          (u) => '${u['email']}'.toLowerCase() == email.trim().toLowerCase(),
        );
    if (taken) {
      throw const ValidationException('Проверьте введённые данные.', {
        'email': 'Такая почта уже зарегистрирована',
      });
    }
    final stamp = DateTime.now().toUtc().toIso8601String();
    final clientId = _db.newId();
    final cardNumber = 100001 + _db.table('client_cards').length;
    _db.table('clients').add({
      'id': clientId,
      'created': stamp,
      'updated': stamp,
      'deletedAt': '',
      'fullName': fullName.trim(),
      'phone':
          '+7 900 000-00-${(_db.table('clients').length % 100).toString().padLeft(2, '0')}',
      'email': email.trim(),
      'birthDate': '',
      'notes': '',
    });
    _db.table('client_cards').add({
      'id': _db.newId(),
      'created': stamp,
      'updated': stamp,
      'deletedAt': '',
      'number': 'BS-$cardNumber',
      'client': clientId,
      'discountPercent': 0,
      'bonusPoints': 0,
      'issuedAt': DateTime.utc(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).toIso8601String(),
    });
    final user = <String, Object?>{
      'id': _db.newId(),
      'created': stamp,
      'updated': stamp,
      'email': email.trim(),
      'password': password,
      'name': fullName.trim(),
      'role': 'client',
      'client': clientId,
      'master': '',
    };
    _db.table('users').add(user);
    _db.save();
    return AppUser.fromJson(Map<String, dynamic>.from(user));
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final id = refreshToken.split('.').skip(1).firstOrNull ?? '';
    final row = _row(id);
    if (row == null) throw const UnauthorizedException();
    return _tokensFor(row);
  }

  @override
  Future<AppUser> me() async {
    final row = _currentId == null ? null : _row(_currentId!);
    if (row == null) throw const UnauthorizedException();
    return AppUser.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> logout(String refreshToken) async {}

  @override
  Future<PageResult<AppUser>> find({
    int page = 1,
    int size = 10,
    RequestToken? token,
  }) async {
    final rows = [..._db.table('users')]
      ..sort((a, b) => '${a['email']}'.compareTo('${b['email']}'));
    return PageResult<AppUser>(
      items: [
        for (final row in rows.skip((page - 1) * size).take(size))
          AppUser.fromJson(Map<String, dynamic>.from(row)),
      ],
      page: page,
      size: size,
      total: rows.length,
    );
  }

  @override
  Future<AppUser> changeRole(String id, Role role) async {
    final row = _row(id);
    if (row == null) throw const NotFoundException();
    row['role'] = role.apiName;
    _db.save();
    return AppUser.fromJson(Map<String, dynamic>.from(row));
  }
}

const demoAccounts = [
  (demoAdminEmail, demoAdminPassword, 'администратор'),
  (demoMasterEmail, demoMasterPassword, 'мастер'),
  (demoClientEmail, demoClientPassword, 'клиент'),
];
