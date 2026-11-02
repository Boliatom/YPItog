typedef Row = Map<String, Object?>;
typedef Tables = Map<String, List<Row>>;

String seedId(String prefix, int n) =>
    '$prefix${n.toString().padLeft(15 - prefix.length, '0')}';

const demoAdminEmail = 'admin@salon.ru';
const demoMasterEmail = 'master@salon.ru';
const demoClientEmail = 'client@salon.ru';
const demoAdminPassword = 'Admin2026!';
const demoMasterPassword = 'Master2026!';
const demoClientPassword = 'Client2026!';

String _iso(DateTime moment) => moment.toUtc().toIso8601String();

String _day(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).toIso8601String();

const _categories = [
  ('Парикмахерские услуги', 'Стрижки, окрашивание и укладки'),
  ('Маникюр и педикюр', 'Уход за руками и ногами, покрытие гель-лаком'),
  ('Косметология', 'Чистка, пилинг и уходовые процедуры для лица'),
  ('Брови и ресницы', 'Коррекция и окрашивание бровей, ламинирование'),
  ('Массаж и СПА', 'Расслабляющий и лечебный массаж'),
];

const _services = [
  (0, 'Женская стрижка', 60, 1800),
  (0, 'Мужская стрижка', 45, 1200),
  (0, 'Окрашивание в один тон', 120, 4500),
  (0, 'Сложное окрашивание', 180, 7500),
  (0, 'Укладка', 45, 1500),
  (1, 'Маникюр классический', 60, 1300),
  (1, 'Маникюр с покрытием гель-лак', 90, 2200),
  (1, 'Педикюр', 90, 2500),
  (1, 'Наращивание ногтей', 150, 3800),
  (2, 'Чистка лица', 75, 3200),
  (2, 'Химический пилинг', 60, 3600),
  (2, 'Уход с маской', 45, 2400),
  (3, 'Коррекция бровей', 30, 900),
  (3, 'Окрашивание бровей', 40, 1100),
  (3, 'Ламинирование ресниц', 60, 2800),
  (4, 'Классический массаж спины', 45, 2000),
  (4, 'Массаж всего тела', 90, 4200),
  (4, 'Антицеллюлитный массаж', 60, 3000),
];

const _masters = [
  (
    'hairdresser',
    'Орлова Екатерина Андреевна',
    '+7 900 111-22-01',
    9,
    [0, 1, 2, 3, 4],
  ),
  ('hairdresser', 'Беляев Дмитрий Олегович', '+7 900 111-22-02', 6, [0, 1, 4]),
  ('nails', 'Смирнова Алина Игоревна', '+7 900 111-22-03', 5, [5, 6, 7, 8]),
  (
    'cosmetologist',
    'Громова Ольга Павловна',
    '+7 900 111-22-04',
    12,
    [9, 10, 11],
  ),
  ('brows', 'Лебедева Мария Сергеевна', '+7 900 111-22-05', 4, [12, 13, 14]),
  ('massage', 'Новиков Артём Викторович', '+7 900 111-22-06', 8, [15, 16, 17]),
];

const _clients = [
  ('Иванова Анна Сергеевна', '+7 911 200-10-01', 'client@salon.ru', 10, 420),
  ('Петрова Юлия Николаевна', '+7 911 200-10-02', 'petrova@mail.ru', 5, 180),
  (
    'Сидорова Наталья Ивановна',
    '+7 911 200-10-03',
    'sidorova@mail.ru',
    15,
    760,
  ),
  ('Кузнецова Ирина Алексеевна', '+7 911 200-10-04', 'kuznecova@mail.ru', 0, 0),
  ('Морозова Елена Дмитриевна', '+7 911 200-10-05', 'morozova@mail.ru', 5, 90),
  (
    'Волкова Светлана Андреевна',
    '+7 911 200-10-06',
    'volkova@mail.ru',
    10,
    300,
  ),
  ('Соколова Дарья Павловна', '+7 911 200-10-07', 'sokolova@mail.ru', 0, 20),
  ('Попов Андрей Сергеевич', '+7 911 200-10-08', 'popov@mail.ru', 5, 140),
  (
    'Михайлова Виктория Олеговна',
    '+7 911 200-10-09',
    'mihaylova@mail.ru',
    20,
    1150,
  ),
  ('Фёдорова Алёна Викторовна', '+7 911 200-10-10', 'fedorova@mail.ru', 0, 0),
];

const _comments = [
  '',
  'Первый визит',
  'Постоянный клиент',
  'Просьба не опаздывать',
  'Аллергия на аммиак',
  '',
];

const _reviewTexts = [
  'Очень довольна результатом, спасибо!',
  'Всё аккуратно и вовремя.',
  'Мастер внимательный, приду ещё.',
  'Хорошо, но пришлось немного подождать.',
  'Отличный сервис и приятная атмосфера.',
];

Tables buildSeed(DateTime now) {
  final stamp = _iso(now.subtract(const Duration(days: 60)));
  Row base(String id) => {
    'id': id,
    'created': stamp,
    'updated': stamp,
    'deletedAt': '',
  };

  final categories = <Row>[
    for (var i = 0; i < _categories.length; i++)
      {
        ...base(seedId('cat', i + 1)),
        'name': _categories[i].$1,
        'description': _categories[i].$2,
      },
  ];

  final services = <Row>[
    for (var i = 0; i < _services.length; i++)
      {
        ...base(seedId('srv', i + 1)),
        'name': _services[i].$2,
        'category': seedId('cat', _services[i].$1 + 1),
        'durationMin': _services[i].$3,
        'price': _services[i].$4,
        'description': '',
        'active': true,
      },
  ];

  final masters = <Row>[
    for (var i = 0; i < _masters.length; i++)
      {
        ...base(seedId('mst', i + 1)),
        'fullName': _masters[i].$2,
        'position': _masters[i].$1,
        'phone': _masters[i].$3,
        'experienceYears': _masters[i].$4,
        'services': [for (final s in _masters[i].$5) seedId('srv', s + 1)],
        'bio': '',
      },
  ];

  final clients = <Row>[
    for (var i = 0; i < _clients.length; i++)
      {
        ...base(seedId('cli', i + 1)),
        'fullName': _clients[i].$1,
        'phone': _clients[i].$2,
        'email': _clients[i].$3,
        'birthDate': _day(DateTime(1985 + i, (i % 12) + 1, 5 + i)),
        'notes': '',
      },
  ];

  final cards = <Row>[
    for (var i = 0; i < _clients.length; i++)
      {
        ...base(seedId('crd', i + 1)),
        'number': 'BS-${(100001 + i).toString()}',
        'client': seedId('cli', i + 1),
        'discountPercent': _clients[i].$4,
        'bonusPoints': _clients[i].$5,
        'issuedAt': _day(now.subtract(Duration(days: 50 - i * 3))),
      },
  ];

  const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final schedules = <Row>[];
  var scheduleNo = 0;
  for (var m = 0; m < _masters.length; m++) {
    final days = m.isEven ? 6 : 5;
    for (var d = 0; d < days; d++) {
      scheduleNo++;
      schedules.add({
        ...base(seedId('sch', scheduleNo)),
        'master': seedId('mst', m + 1),
        'weekday': weekdayKeys[d],
        'startTime': m < 3 ? '10:00' : '09:00',
        'endTime': m < 3 ? '19:00' : '18:00',
      });
    }
  }

  final appointments = <Row>[];
  final reviews = <Row>[];
  var appNo = 0;
  var reviewNo = 0;
  final today = DateTime(now.year, now.month, now.day);
  for (var offset = -24; offset <= 12; offset++) {
    final day = today.add(Duration(days: offset));
    if (day.weekday == DateTime.sunday) continue;
    for (var m = 0; m < _masters.length; m++) {
      final worksDays = m.isEven ? 6 : 5;
      if (day.weekday > worksDays || (offset + m) % 3 == 0) continue;
      final master = _masters[m];
      final serviceIndex = master.$5[(offset.abs() + m) % master.$5.length];
      final service = _services[serviceIndex];
      final startHour = (m < 3 ? 10 : 9) + ((offset.abs() + m) % 3) * 3;
      final start = DateTime(day.year, day.month, day.day, startHour, 0);
      final end = start.add(Duration(minutes: service.$3));
      final clientIndex = (offset.abs() * 3 + m) % _clients.length;
      final client = _clients[clientIndex];
      final past = end.isBefore(now);
      final cancelled = !past && (offset + m) % 7 == 0;
      final status = cancelled
          ? 'cancelled'
          : past
          ? 'done'
          : (offset <= 1 ? 'confirmed' : 'new');
      appNo++;
      final appId = seedId('app', appNo);
      appointments.add({
        ...base(appId),
        'client': seedId('cli', clientIndex + 1),
        'master': seedId('mst', m + 1),
        'services': [seedId('srv', serviceIndex + 1)],
        'startsAt': _iso(start),
        'endsAt': _iso(end),
        'status': status,
        'discountPercent': client.$4,
        'totalPrice': (service.$4 * (100 - client.$4) / 100).round(),
        'comment': _comments[appNo % _comments.length],
      });
      if (status == 'done' && appNo % 3 != 0) {
        reviewNo++;
        reviews.add({
          ...base(seedId('rev', reviewNo)),
          'appointment': appId,
          'client': seedId('cli', clientIndex + 1),
          'master': seedId('mst', m + 1),
          'rating': 3 + (appNo % 3),
          'text': _reviewTexts[appNo % _reviewTexts.length],
        });
      }
    }
  }

  final users = <Row>[
    {
      ...base('usr000000000001'),
      'email': demoAdminEmail,
      'password': demoAdminPassword,
      'name': 'Администратор салона',
      'role': 'admin',
      'client': '',
      'master': '',
    },
    {
      ...base('usr000000000002'),
      'email': demoMasterEmail,
      'password': demoMasterPassword,
      'name': _masters[0].$2,
      'role': 'master',
      'client': '',
      'master': seedId('mst', 1),
    },
    {
      ...base('usr000000000003'),
      'email': demoClientEmail,
      'password': demoClientPassword,
      'name': _clients[0].$1,
      'role': 'client',
      'client': seedId('cli', 1),
      'master': '',
    },
  ];

  return {
    'service_categories': categories,
    'services': services,
    'masters': masters,
    'clients': clients,
    'client_cards': cards,
    'appointments': appointments,
    'reviews': reviews,
    'schedules': schedules,
    'users': users,
  };
}
