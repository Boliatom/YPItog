import 'package:flutter/material.dart';

import '../core/date_format.dart';
import '../models/rec.dart';
import 'entity_schema.dart';
import 'field_def.dart';

const appointmentStatuses = [
  Option('new', 'Новая'),
  Option('confirmed', 'Подтверждена'),
  Option('done', 'Выполнена'),
  Option('cancelled', 'Отменена'),
];

const weekdays = [
  Option('mon', 'Понедельник'),
  Option('tue', 'Вторник'),
  Option('wed', 'Среда'),
  Option('thu', 'Четверг'),
  Option('fri', 'Пятница'),
  Option('sat', 'Суббота'),
  Option('sun', 'Воскресенье'),
];

const masterPositions = [
  Option('hairdresser', 'Парикмахер-стилист'),
  Option('nails', 'Мастер маникюра'),
  Option('cosmetologist', 'Косметолог'),
  Option('brows', 'Бровист'),
  Option('massage', 'Массажист'),
];

String weekdayKey(DateTime day) => weekdays[day.weekday - 1].value;

String _label(Option option) => option.label;

String optionText(List<Option> options, String value) {
  for (final option in options) {
    if (option.value == value) return _label(option);
  }
  return value;
}

const _timePattern = r'^([01]\d|2[0-3]):[0-5]\d$';

final EntitySchema categoriesSchema = EntitySchema(
  collection: 'service_categories',
  sectionName: 'categories',
  titlePlural: 'Категории услуг',
  titleSingular: 'Категория',
  accusative: 'категорию',
  icon: Icons.category_outlined,
  searchLabel: 'Поиск по названию категории',
  searchFields: const ['name', 'description'],
  defaultSort: 'name',
  title: (r) => r.text('name'),
  subtitle: (r) => r.text('description'),
  fields: const [
    FieldDef(
      'name',
      'Название',
      FieldKind.text,
      required: true,
      minLength: 2,
      maxLength: 60,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'description',
      'Описание',
      FieldKind.longText,
      maxLength: 300,
      inList: true,
    ),
  ],
);

final EntitySchema servicesSchema = EntitySchema(
  collection: 'services',
  titlePlural: 'Услуги',
  titleSingular: 'Услуга',
  accusative: 'услугу',
  icon: Icons.spa_outlined,
  searchLabel: 'Поиск по названию и описанию услуги',
  searchFields: const ['name', 'description'],
  defaultSort: 'name',
  title: (r) => r.text('name'),
  subtitle: (r) =>
      '${r.labelOf('category')} · ${r.integer('durationMin') ?? 0} мин · '
      '${numText(r.number('price') ?? 0)} ₽',
  filters: const [
    FilterDef(
      'category',
      'Категория',
      FilterType.refEquals,
      'category',
      target: 'service_categories',
    ),
    FilterDef('priceFrom', 'Цена от', FilterType.numMin, 'price'),
    FilterDef('priceTo', 'Цена до', FilterType.numMax, 'price'),
  ],
  fields: const [
    FieldDef(
      'name',
      'Название',
      FieldKind.text,
      required: true,
      minLength: 2,
      maxLength: 80,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'category',
      'Категория',
      FieldKind.relation,
      required: true,
      target: 'service_categories',
      inList: true,
    ),
    FieldDef(
      'durationMin',
      'Длительность',
      FieldKind.integer,
      required: true,
      min: 5,
      max: 480,
      unit: 'мин',
      inList: true,
      sortable: true,
      hint: 'От 5 до 480 минут',
    ),
    FieldDef(
      'price',
      'Цена',
      FieldKind.number,
      required: true,
      min: 1,
      max: 100000,
      unit: '₽',
      inList: true,
      sortable: true,
    ),
    FieldDef('description', 'Описание', FieldKind.longText, maxLength: 500),
    FieldDef('active', 'Доступна для записи', FieldKind.boolean),
  ],
);

final EntitySchema mastersSchema = EntitySchema(
  collection: 'masters',
  titlePlural: 'Мастера',
  titleSingular: 'Мастер',
  accusative: 'мастера',
  icon: Icons.content_cut,
  searchLabel: 'Поиск по имени и телефону мастера',
  searchFields: const ['fullName', 'phone'],
  defaultSort: 'fullName',
  title: (r) => r.text('fullName'),
  subtitle: (r) =>
      '${optionText(masterPositions, r.text('position'))} · стаж '
      '${r.integer('experienceYears') ?? 0} лет',
  filters: const [
    FilterDef(
      'position',
      'Специальность',
      FilterType.optionEquals,
      'position',
      options: masterPositions,
    ),
    FilterDef(
      'service',
      'Услуга',
      FilterType.refContains,
      'services',
      target: 'services',
    ),
    FilterDef('expFrom', 'Стаж от, лет', FilterType.numMin, 'experienceYears'),
  ],
  fields: const [
    FieldDef(
      'fullName',
      'ФИО',
      FieldKind.text,
      required: true,
      minLength: 2,
      maxLength: 80,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'position',
      'Специальность',
      FieldKind.select,
      required: true,
      options: masterPositions,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'phone',
      'Телефон',
      FieldKind.phone,
      required: true,
      inList: true,
      hint: '+7 900 123-45-67',
    ),
    FieldDef(
      'experienceYears',
      'Стаж',
      FieldKind.integer,
      required: true,
      min: 0,
      max: 60,
      unit: 'лет',
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'services',
      'Выполняемые услуги',
      FieldKind.relations,
      required: true,
      target: 'services',
      inList: true,
    ),
    FieldDef('bio', 'О мастере', FieldKind.longText, maxLength: 500),
  ],
);

final EntitySchema clientsSchema = EntitySchema(
  collection: 'clients',
  titlePlural: 'Клиенты',
  titleSingular: 'Клиент',
  accusative: 'клиента',
  icon: Icons.people_outline,
  searchLabel: 'Поиск по имени, телефону и почте',
  searchFields: const ['fullName', 'phone', 'email'],
  defaultSort: 'fullName',
  title: (r) => r.text('fullName'),
  subtitle: (r) => r.text('phone'),
  filters: const [
    FilterDef('birthFrom', 'Родились с', FilterType.dateFrom, 'birthDate'),
    FilterDef('birthTo', 'Родились по', FilterType.dateTo, 'birthDate'),
    FilterDef('createdFrom', 'Пришли с', FilterType.dateFrom, 'created'),
  ],
  fields: const [
    FieldDef(
      'fullName',
      'ФИО',
      FieldKind.text,
      required: true,
      minLength: 2,
      maxLength: 80,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'phone',
      'Телефон',
      FieldKind.phone,
      required: true,
      inList: true,
      hint: '+7 900 123-45-67',
    ),
    FieldDef('email', 'Почта', FieldKind.email, inList: true),
    FieldDef(
      'birthDate',
      'Дата рождения',
      FieldKind.date,
      pastOnly: true,
      sortable: true,
    ),
    FieldDef('notes', 'Заметки', FieldKind.longText, maxLength: 300),
  ],
);

final EntitySchema cardsSchema = EntitySchema(
  collection: 'client_cards',
  sectionName: 'cards',
  titlePlural: 'Карты клиентов',
  titleSingular: 'Карта клиента',
  accusative: 'карту клиента',
  icon: Icons.card_membership_outlined,
  searchLabel: 'Поиск по номеру карты',
  searchFields: const ['number'],
  defaultSort: 'number',
  title: (r) => r.text('number'),
  subtitle: (r) =>
      '${r.labelOf('client')} · скидка ${r.integer('discountPercent') ?? 0}%',
  filters: const [
    FilterDef(
      'client',
      'Клиент',
      FilterType.refEquals,
      'client',
      target: 'clients',
    ),
    FilterDef(
      'discountFrom',
      'Скидка от, %',
      FilterType.numMin,
      'discountPercent',
    ),
    FilterDef(
      'discountTo',
      'Скидка до, %',
      FilterType.numMax,
      'discountPercent',
    ),
    FilterDef('issuedFrom', 'Выдана с', FilterType.dateFrom, 'issuedAt'),
  ],
  fields: const [
    FieldDef(
      'number',
      'Номер карты',
      FieldKind.text,
      required: true,
      pattern: r'^BS-\d{6}$',
      patternMessage: 'Формат: BS-000123',
      hint: 'BS-000123',
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'client',
      'Клиент',
      FieldKind.relation,
      required: true,
      target: 'clients',
      inList: true,
      immutable: true,
    ),
    FieldDef(
      'discountPercent',
      'Скидка',
      FieldKind.integer,
      required: true,
      min: 0,
      max: 30,
      unit: '%',
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'bonusPoints',
      'Бонусные баллы',
      FieldKind.integer,
      required: true,
      min: 0,
      max: 1000000,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'issuedAt',
      'Дата выдачи',
      FieldKind.date,
      required: true,
      pastOnly: true,
      sortable: true,
    ),
  ],
);

final EntitySchema appointmentsSchema = EntitySchema(
  collection: 'appointments',
  titlePlural: 'Записи',
  titleSingular: 'Запись',
  accusative: 'запись',
  icon: Icons.event_note_outlined,
  searchLabel: 'Поиск по комментарию',
  searchFields: const ['comment'],
  defaultSort: 'startsAt',
  defaultAscending: false,
  title: (r) =>
      '${formatDateTime(r.date('startsAt'))} · ${r.labelOf('client')}',
  subtitle: (r) =>
      '${r.labelOf('master')} · ${optionText(appointmentStatuses, r.text('status'))}',
  filters: const [
    FilterDef(
      'status',
      'Статус',
      FilterType.optionEquals,
      'status',
      options: appointmentStatuses,
    ),
    FilterDef(
      'master',
      'Мастер',
      FilterType.refEquals,
      'master',
      target: 'masters',
    ),
    FilterDef(
      'client',
      'Клиент',
      FilterType.refEquals,
      'client',
      target: 'clients',
    ),
    FilterDef('from', 'С даты', FilterType.dateFrom, 'startsAt'),
    FilterDef('to', 'По дату', FilterType.dateTo, 'startsAt'),
  ],
  extraValidate: (v) {
    final start = v['startsAt'];
    final end = v['endsAt'];
    if (start is DateTime && end is DateTime && !end.isAfter(start)) {
      return {'endsAt': 'Окончание должно быть позже начала'};
    }
    return const {};
  },
  fields: const [
    FieldDef(
      'client',
      'Клиент',
      FieldKind.relation,
      required: true,
      target: 'clients',
      inList: true,
    ),
    FieldDef(
      'master',
      'Мастер',
      FieldKind.relation,
      required: true,
      target: 'masters',
      inList: true,
    ),
    FieldDef(
      'services',
      'Услуги',
      FieldKind.relations,
      required: true,
      target: 'services',
      narrowedBy: 'master',
      inList: true,
    ),
    FieldDef(
      'startsAt',
      'Начало',
      FieldKind.dateTime,
      required: true,
      inList: true,
      sortable: true,
    ),
    FieldDef('endsAt', 'Окончание', FieldKind.dateTime, computed: true),
    FieldDef(
      'status',
      'Статус',
      FieldKind.select,
      required: true,
      options: appointmentStatuses,
      inList: true,
      sortable: true,
    ),
    FieldDef(
      'discountPercent',
      'Скидка',
      FieldKind.integer,
      min: 0,
      max: 100,
      unit: '%',
      computed: true,
    ),
    FieldDef(
      'totalPrice',
      'Стоимость',
      FieldKind.number,
      min: 0,
      unit: '₽',
      inList: true,
      sortable: true,
      computed: true,
    ),
    FieldDef('comment', 'Комментарий', FieldKind.longText, maxLength: 300),
  ],
);

final EntitySchema reviewsSchema = EntitySchema(
  collection: 'reviews',
  titlePlural: 'Отзывы',
  titleSingular: 'Отзыв',
  accusative: 'отзыв',
  icon: Icons.star_outline,
  searchLabel: 'Поиск по тексту отзыва',
  searchFields: const ['text'],
  defaultSort: 'created',
  defaultAscending: false,
  title: (r) => 'Оценка ${r.integer('rating') ?? 0} из 5',
  subtitle: (r) => '${r.labelOf('master')}: ${r.text('text')}',
  filters: const [
    FilterDef(
      'master',
      'Мастер',
      FilterType.refEquals,
      'master',
      target: 'masters',
    ),
    FilterDef('ratingFrom', 'Оценка от', FilterType.numMin, 'rating'),
    FilterDef('ratingTo', 'Оценка до', FilterType.numMax, 'rating'),
  ],
  fields: const [
    FieldDef(
      'appointment',
      'Запись',
      FieldKind.relation,
      required: true,
      target: 'appointments',
      immutable: true,
    ),
    FieldDef(
      'client',
      'Клиент',
      FieldKind.relation,
      required: true,
      target: 'clients',
      inList: true,
      immutable: true,
    ),
    FieldDef(
      'master',
      'Мастер',
      FieldKind.relation,
      required: true,
      target: 'masters',
      inList: true,
      immutable: true,
    ),
    FieldDef(
      'rating',
      'Оценка',
      FieldKind.integer,
      required: true,
      min: 1,
      max: 5,
      inList: true,
      sortable: true,
      hint: 'От 1 до 5',
    ),
    FieldDef(
      'text',
      'Текст отзыва',
      FieldKind.longText,
      maxLength: 500,
      inList: true,
    ),
  ],
);

final EntitySchema schedulesSchema = EntitySchema(
  collection: 'schedules',
  titlePlural: 'График работы',
  titleSingular: 'Смена',
  accusative: 'смену',
  icon: Icons.schedule,
  searchLabel: 'Поиск по мастеру недоступен, используйте фильтры',
  searchFields: const [],
  defaultSort: 'weekday',
  title: (r) =>
      '${r.labelOf('master')}: ${optionText(weekdays, r.text('weekday'))}',
  subtitle: (r) => '${r.text('startTime')}–${r.text('endTime')}',
  filters: const [
    FilterDef(
      'master',
      'Мастер',
      FilterType.refEquals,
      'master',
      target: 'masters',
    ),
    FilterDef(
      'weekday',
      'День недели',
      FilterType.optionEquals,
      'weekday',
      options: weekdays,
    ),
  ],
  extraValidate: (v) {
    final start = '${v['startTime'] ?? ''}';
    final end = '${v['endTime'] ?? ''}';
    if (start.isNotEmpty && end.isNotEmpty && end.compareTo(start) <= 0) {
      return {'endTime': 'Окончание должно быть позже начала'};
    }
    return const {};
  },
  fields: const [
    FieldDef(
      'master',
      'Мастер',
      FieldKind.relation,
      required: true,
      target: 'masters',
      inList: true,
    ),
    FieldDef(
      'weekday',
      'День недели',
      FieldKind.select,
      required: true,
      options: weekdays,
      inList: true,
    ),
    FieldDef(
      'startTime',
      'Начало смены',
      FieldKind.text,
      required: true,
      pattern: _timePattern,
      patternMessage: 'Формат: ЧЧ:ММ',
      hint: '09:00',
      inList: true,
    ),
    FieldDef(
      'endTime',
      'Конец смены',
      FieldKind.text,
      required: true,
      pattern: _timePattern,
      patternMessage: 'Формат: ЧЧ:ММ',
      hint: '18:00',
      inList: true,
    ),
  ],
);

final List<EntitySchema> allSchemas = [
  categoriesSchema,
  servicesSchema,
  mastersSchema,
  clientsSchema,
  cardsSchema,
  appointmentsSchema,
  reviewsSchema,
  schedulesSchema,
];

final Map<String, EntitySchema> _byCollection = {
  for (final s in allSchemas) s.collection: s,
};

final Map<String, EntitySchema> _bySection = {
  for (final s in allSchemas) s.section: s,
};

EntitySchema schemaFor(String collection) {
  final schema = _byCollection[collection];
  if (schema == null) {
    throw ArgumentError('Неизвестная коллекция: $collection');
  }
  return schema;
}

EntitySchema? schemaForSection(String section) => _bySection[section];

String titleOf(Rec rec) => schemaFor(rec.collection).title(rec);
