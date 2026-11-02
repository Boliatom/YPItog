import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/auth/role.dart';
import 'package:salon_app/core/api_client.dart';
import 'package:salon_app/core/api_exceptions.dart';
import 'package:salon_app/domain/stats.dart';
import 'package:salon_app/models/rec.dart';
import 'package:salon_app/models/rec_query.dart';
import 'package:salon_app/repositories/auth_api.dart';
import 'package:salon_app/repositories/pocketbase_repository.dart';
import 'package:salon_app/schema/schemas.dart';

class FakeCall {
  FakeCall(this.method, this.uri, this.body, this.headers);

  final String method;
  final Uri uri;
  final Object? body;
  final Map<String, dynamic> headers;
}

class FakeServer implements HttpClientAdapter {
  FakeServer(this.reply);

  final (int, Object?) Function(FakeCall call) reply;
  final List<FakeCall> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final call = FakeCall(
      options.method,
      options.uri,
      options.data,
      Map<String, dynamic>.from(options.headers),
    );
    calls.add(call);
    final (status, body) = reply(call);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioFor(FakeServer server, {String? Function()? token}) {
  final dio = buildDio(
    baseUrl: 'http://pb.test/api',
    tokenProvider: token,
    logRequests: false,
  );
  dio.httpClientAdapter = server;
  return dio;
}

String fakeJwt(int exp) {
  String part(Map<String, Object?> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.signature';
}

void main() {
  final listBody = {
    'page': 2,
    'perPage': 10,
    'totalItems': 21,
    'totalPages': 3,
    'items': [
      {
        'id': 'srv1',
        'name': 'Стрижка',
        'category': 'cat1',
        'durationMin': 60,
        'price': 1800,
        'active': true,
        'deletedAt': '',
        'expand': {
          'category': {'id': 'cat1', 'name': 'Волосы'},
        },
      },
    ],
  };

  test('список: параметры запроса и разбор страницы', () async {
    final server = FakeServer((_) => (200, listBody));
    final repo = PocketBaseRepository(dioFor(server), servicesSchema);
    final page = await repo.find(
      RecQuery.fromParams(servicesSchema, {
        'page': '2',
        'sort': 'price,desc',
        'search': 'стриж',
        'category': 'cat1',
      }),
    );
    final params = server.calls.single.uri.queryParameters;
    expect(server.calls.single.uri.path, '/api/collections/services/records');
    expect(params['page'], '2');
    expect(params['perPage'], '10');
    expect(params['sort'], '-price');
    expect(params['expand'], 'category');
    expect(params['filter'], contains('category = "cat1"'));
    expect(params['filter'], contains('name ~ "стриж"'));
    expect(page.total, 21);
    expect(page.items.single.labelOf('category'), 'Волосы');
  });

  test('токен передаётся в заголовке Authorization', () async {
    final server = FakeServer((_) => (200, listBody));
    final repo = PocketBaseRepository(
      dioFor(server, token: () => 'jwt-token'),
      servicesSchema,
    );
    await repo.find(RecQuery(schema: servicesSchema));
    expect(server.calls.single.headers['Authorization'], 'jwt-token');
  });

  test('ошибка 400 превращается в ошибки полей формы', () async {
    final server = FakeServer(
      (_) => (
        400,
        {
          'status': 400,
          'message': 'Failed to create record.',
          'data': {
            'name': {
              'code': 'validation_not_unique',
              'message': 'Value must be unique.',
            },
            'price': {
              'code': 'validation_min_number_constraint',
              'message': 'Must be >= 0',
            },
          },
        },
      ),
    );
    final repo = PocketBaseRepository(dioFor(server), servicesSchema);
    await expectLater(
      repo.create({'name': 'Стрижка', 'price': -1}),
      throwsA(
        isA<ValidationException>().having((e) => e.errors, 'поля', {
          'name': 'Такое значение уже используется',
          'price': 'Число меньше допустимого',
        }),
      ),
    );
  });

  test('ошибки 404, 409 и 500 получают понятные тексты', () async {
    for (final (status, matcher) in [
      (404, isA<NotFoundException>()),
      (409, isA<ConflictException>()),
      (500, isA<ServerException>()),
    ]) {
      final server = FakeServer(
        (_) => (status, {'message': 'Это время у мастера уже занято.'}),
      );
      final repo = PocketBaseRepository(dioFor(server), appointmentsSchema);
      await expectLater(repo.softDelete('x'), throwsA(matcher));
    }
  });

  test('логическое удаление и восстановление меняют deletedAt', () async {
    final server = FakeServer((_) => (200, {'id': 'srv1'}));
    final repo = PocketBaseRepository(dioFor(server), servicesSchema);
    await repo.softDelete('srv1');
    await repo.restore('srv1');
    expect(server.calls[0].method, 'PATCH');
    expect((server.calls[0].body as Map)['deletedAt'], isNotEmpty);
    expect((server.calls[1].body as Map)['deletedAt'], '');
  });

  test('вход: разбор токена и срок его действия', () async {
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 900;
    final token = fakeJwt(exp);
    final server = FakeServer(
      (_) => (
        200,
        {
          'token': token,
          'record': {
            'id': 'u1',
            'email': 'a@salon.ru',
            'name': 'Анна',
            'role': 'master',
            'master': 'm1',
          },
        },
      ),
    );
    final api = PocketBaseAuthApi(dioFor(server));
    final tokens = await api.login('a@salon.ru', 'secret');
    expect(tokens.user.role, Role.master);
    expect(tokens.user.masterId, 'm1');
    expect(tokens.accessLifetime.inSeconds, inInclusiveRange(890, 900));
    expect((server.calls.single.body as Map)['identity'], 'a@salon.ru');
  });

  test('срок токена без разбора берётся по умолчанию', () {
    expect(tokenLifetime('not-a-jwt'), const Duration(minutes: 15));
  });

  test('статистика считает выручку, мастеров и услуги', () {
    Rec done(String id, num price, String master, List<String> services) => Rec(
      collection: 'appointments',
      id: id,
      values: {'status': 'done', 'totalPrice': price, 'master': master},
      labels: {
        'master': [master],
        'services': services,
      },
    );
    final stats = computeStats([
      done('1', 1000, 'Орлова', ['Стрижка']),
      done('2', 500, 'Орлова', ['Укладка', 'Стрижка']),
      done('3', 3000, 'Громова', ['Чистка лица']),
      const Rec(
        collection: 'appointments',
        id: '4',
        values: {'status': 'cancelled', 'totalPrice': 9999},
      ),
    ]);
    expect(stats.count, 3);
    expect(stats.revenue, 4500);
    expect(stats.average, 1500);
    expect(stats.byMaster.first.label, 'Громова');
    expect(stats.byMaster.first.value, 3000);
    expect(stats.byService.first.label, 'Стрижка');
    expect(stats.byService.first.value, 2);
  });
}
