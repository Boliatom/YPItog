import 'package:flutter_test/flutter_test.dart';
import 'package:salon_app/models/rec_query.dart';
import 'package:salon_app/repositories/pocketbase_repository.dart';
import 'package:salon_app/schema/schemas.dart';

void main() {
  group('проверка полей по схеме', () {
    test('пустая услуга: ошибки у обязательных полей', () {
      final errors = servicesSchema.validate(servicesSchema.draftFrom(null));
      expect(
        errors.keys,
        containsAll(['name', 'category', 'durationMin', 'price']),
      );
      expect(errors['name'], 'Обязательное поле');
    });

    test('диапазоны чисел', () {
      final draft = servicesSchema.draftFrom(null)
        ..['name'] = 'Стрижка'
        ..['category'] = 'cat1'
        ..['durationMin'] = '3'
        ..['price'] = '-5';
      final errors = servicesSchema.validate(draft);
      expect(errors['durationMin'], 'От 5 до 480');
      expect(errors['price'], 'От 1 до 100000');
    });

    test('корректная услуга проходит', () {
      final draft = servicesSchema.draftFrom(null)
        ..['name'] = 'Стрижка'
        ..['category'] = 'cat1'
        ..['durationMin'] = '60'
        ..['price'] = '1500,50';
      expect(servicesSchema.validate(draft), isEmpty);
      final values = servicesSchema.valuesFrom(draft);
      expect(values['durationMin'], 60);
      expect(values['price'], 1500.5);
    });

    test('номер карты и телефон', () {
      final card = cardsSchema.field('number')!;
      expect(cardsSchema.validateField(card, 'BS-12'), 'Формат: BS-000123');
      expect(cardsSchema.validateField(card, 'BS-000123'), isNull);
      final phone = clientsSchema.field('phone')!;
      expect(clientsSchema.validateField(phone, 'abc'), isNotNull);
      expect(clientsSchema.validateField(phone, '+7 900 123-45-67'), isNull);
    });

    test('конец смены должен быть позже начала', () {
      final draft = schedulesSchema.draftFrom(null)
        ..['master'] = 'm1'
        ..['weekday'] = 'mon'
        ..['startTime'] = '18:00'
        ..['endTime'] = '10:00';
      expect(
        schedulesSchema.validate(draft)['endTime'],
        'Окончание должно быть позже начала',
      );
    });
  });

  group('разбор ответа PocketBase', () {
    final json = {
      'id': 'abc123',
      'created': '2026-11-01 10:00:00.000Z',
      'updated': '2026-11-01 10:00:00.000Z',
      'name': 'Маникюр',
      'category': 'cat1',
      'durationMin': 60,
      'price': 1300,
      'description': '',
      'active': true,
      'deletedAt': '',
      'expand': {
        'category': {'id': 'cat1', 'name': 'Ногти', 'description': ''},
      },
    };

    test('значения и подписи связей', () {
      final rec = servicesSchema.parse(json, schemaFor);
      expect(rec.id, 'abc123');
      expect(rec.text('name'), 'Маникюр');
      expect(rec.integer('durationMin'), 60);
      expect(rec.number('price'), 1300);
      expect(rec.flag('active'), isTrue);
      expect(rec.labelOf('category'), 'Ногти');
      expect(rec.deletedAt, isNull);
      expect(servicesSchema.subtitle(rec), 'Ногти · 60 мин · 1300 ₽');
    });

    test('удалённая запись и тело запроса', () {
      final rec = servicesSchema.parse({
        ...json,
        'deletedAt': '2026-11-02 09:00:00.000Z',
      }, schemaFor);
      expect(rec.isDeleted, isTrue);
      final body = servicesSchema.toBody({
        'name': 'Новая',
        'durationMin': 45,
        'deletedAt': null,
      });
      expect(body['deletedAt'], '');
      expect(body['durationMin'], 45);
    });
  });

  group('условия отбора', () {
    test('адрес списка восстанавливает запрос', () {
      final query = RecQuery.fromParams(servicesSchema, {
        'search': ' гель ',
        'category': 'cat1',
        'priceFrom': '1000',
        'sort': 'price,desc',
        'page': '3',
        'size': '25',
        'unknown': 'x',
      });
      expect(query.search, 'гель');
      expect(query.filters, {'category': 'cat1', 'priceFrom': '1000'});
      expect(query.sortField, 'price');
      expect(query.sortAscending, isFalse);
      expect(query.page, 3);
      final again = RecQuery.fromParams(servicesSchema, query.toUrlParams());
      expect(again, query);
    });

    test('недопустимые значения отбрасываются', () {
      final query = RecQuery.fromParams(appointmentsSchema, {
        'status': 'hacked',
        'from': '2026-13-45',
        'master': 'a b',
        'sort': 'password,asc',
        'page': '-4',
      });
      expect(query.filters, isEmpty);
      expect(query.sortField, 'startsAt');
      expect(query.page, 1);
    });

    test('фильтр PocketBase собирается из запроса', () {
      final query = RecQuery.fromParams(servicesSchema, {
        'search': 'гель "лак"',
        'category': 'cat1',
        'priceFrom': '1000',
        'priceTo': '3000',
      });
      final filter = buildPocketBaseFilter(query);
      expect(filter, contains('deletedAt = ""'));
      expect(filter, contains(r'name ~ "гель \"лак\""'));
      expect(filter, contains('category = "cat1"'));
      expect(filter, contains('price >= 1000'));
      expect(filter, contains('price <= 3000'));
    });

    test('показ удалённых убирает условие deletedAt', () {
      final query = RecQuery.fromParams(servicesSchema, {
        'includeDeleted': 'true',
      });
      expect(buildPocketBaseFilter(query), isEmpty);
    });
  });
}
