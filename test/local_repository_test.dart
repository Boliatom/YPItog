import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/auth/app_user.dart';
import 'package:salon_app/core/api_exceptions.dart';
import 'package:salon_app/models/rec.dart';
import 'package:salon_app/models/rec_query.dart';
import 'package:salon_app/repositories/local_database.dart';
import 'package:salon_app/repositories/local_repository.dart';
import 'package:salon_app/repositories/record_repository.dart';
import 'package:salon_app/schema/schemas.dart';

void main() {
  final now = DateTime(2026, 11, 2, 12);
  late LocalDatabase db;
  late AppUser current;
  late SalonRepositories repos;

  AppUser userRow(String id) =>
      AppUser.fromJson(Map<String, dynamic>.from(db.find('users', id)!));

  setUp(() {
    db = LocalDatabase.seeded(now: now);
    current = userRow('usr000000000001');
    repos = createLocalRepositories(db, () => current);
  });

  Map<String, Object?> newService({String name = 'Новая услуга'}) => {
    'name': name,
    'category': 'cat000000000001',
    'durationMin': 40,
    'price': 900,
    'description': '',
    'active': true,
  };

  test('список: сортировка, страницы и поиск на стороне хранилища', () async {
    final all = await repos.services.find(RecQuery(schema: servicesSchema));
    expect(all.total, 18);
    expect(all.items.length, 10);
    final names = all.items.map((r) => r.text('name')).toList();
    expect(
      names,
      [...names]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    );

    final found = await repos.services.find(
      RecQuery(schema: servicesSchema, search: 'массаж'),
    );
    expect(found.total, 3);

    final byCategory = await repos.services.find(
      RecQuery(
        schema: servicesSchema,
        filters: {'category': 'cat000000000002', 'priceTo': '2300'},
      ),
    );
    expect(
      byCategory.items.map((r) => r.text('name')),
      containsAll(['Маникюр классический', 'Маникюр с покрытием гель-лак']),
    );
  });

  test('создание с проверкой и уникальностью названия', () async {
    final created = await repos.services.create(newService());
    expect(created.text('name'), 'Новая услуга');
    expect(created.labelOf('category'), 'Парикмахерские услуги');

    await expectLater(
      repos.services.create(newService()),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['name'],
          'ошибка поля',
          contains('уже используется'),
        ),
      ),
    );
    await expectLater(
      repos.services.create({...newService(name: 'Другая'), 'price': -1}),
      throwsA(isA<ValidationException>()),
    );
  });

  test('логическое удаление, показ удалённых и восстановление', () async {
    await repos.services.softDelete('srv000000000001');
    final hidden = await repos.services.find(RecQuery(schema: servicesSchema));
    expect(hidden.total, 17);
    final shown = await repos.services.find(
      RecQuery(schema: servicesSchema, includeDeleted: true),
    );
    expect(shown.total, 18);
    await repos.services.restore('srv000000000001');
    final back = await repos.services.find(RecQuery(schema: servicesSchema));
    expect(back.total, 18);
  });

  test('множественное удаление скрывает все выбранные записи', () async {
    final count = await repos.services.deleteMany([
      'srv000000000001',
      'srv000000000002',
      'srv000000000003',
    ]);
    expect(count, 3);
    final left = await repos.services.find(RecQuery(schema: servicesSchema));
    expect(left.total, 15);
  });

  test('физическое удаление используемой записи запрещено', () async {
    await expectLater(
      repos.categories.hardDelete('cat000000000001'),
      throwsA(isA<ConflictException>()),
    );
    final fresh = await repos.services.create(newService(name: 'Временная'));
    await repos.services.hardDelete(fresh.id);
    expect(await repos.services.findById(fresh.id), isNull);
  });

  group('записи', () {
    Rec upcoming() {
      final rows = db
          .table('appointments')
          .where(
            (r) =>
                r['status'] == 'new' &&
                DateTime.parse('${r['startsAt']}').isAfter(now),
          );
      return repos.appointments.schema.parse({
        ...rows.first,
        'expand': <String, Object?>{},
      }, schemaFor);
    }

    test('пересечение времени у мастера даёт конфликт 409', () async {
      final taken = upcoming();
      await expectLater(
        repos.appointments.create({
          'client': 'cli000000000002',
          'master': taken.ref('master'),
          'services': taken.refs('services'),
          'startsAt': taken.date('startsAt'),
          'endsAt': taken.date('endsAt'),
          'status': 'new',
          'discountPercent': 0,
          'totalPrice': 1000,
          'comment': '',
        }),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'текст',
            contains('занято'),
          ),
        ),
      );
    });

    test('клиент видит только свои записи и не пишет за других', () async {
      current = userRow('usr000000000003');
      final page = await repos.appointments.find(
        RecQuery(schema: appointmentsSchema, size: 50),
      );
      expect(page.total, greaterThan(0));
      expect(
        page.items.every((r) => r.ref('client') == 'cli000000000001'),
        isTrue,
      );

      final taken = upcoming();
      await expectLater(
        repos.appointments.create({
          'client': 'cli000000000002',
          'master': taken.ref('master'),
          'services': taken.refs('services'),
          'startsAt': DateTime(2030, 1, 1, 10),
          'endsAt': DateTime(2030, 1, 1, 11),
          'status': 'new',
          'comment': '',
        }),
        throwsA(isA<ForbiddenException>()),
      );
      await expectLater(
        repos.clients
            .find(RecQuery(schema: clientsSchema))
            .then((p) => p.total),
        completion(1),
      );
    });

    test('клиенту закрыты правки каталога', () async {
      current = userRow('usr000000000003');
      await expectLater(
        repos.services.create(newService()),
        throwsA(isA<ForbiddenException>()),
      );
      await expectLater(
        repos.services.softDelete('srv000000000001'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}
