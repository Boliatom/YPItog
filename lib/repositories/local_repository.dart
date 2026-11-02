import '../auth/app_user.dart';
import '../auth/role.dart';
import '../core/api_exceptions.dart';
import '../core/request_token.dart';
import '../domain/booking_rules.dart';
import '../models/json_values.dart';
import '../models/page_result.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../schema/entity_schema.dart';
import '../schema/field_def.dart';
import '../schema/schemas.dart';
import 'local_database.dart';
import 'record_repository.dart';
import 'seed_data.dart';

const _uniqueKeys = <String, List<List<String>>>{
  'service_categories': [
    ['name'],
  ],
  'services': [
    ['name'],
  ],
  'client_cards': [
    ['number'],
    ['client'],
  ],
  'reviews': [
    ['appointment'],
  ],
  'schedules': [
    ['master', 'weekday'],
  ],
};

class LocalRepository implements RecordRepository {
  LocalRepository(
    this._db,
    this.schema,
    this._session, {
    this.latency = Duration.zero,
  });

  final LocalDatabase _db;
  final AppUser? Function() _session;
  final Duration latency;

  @override
  final EntitySchema schema;

  String get _name => schema.collection;

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  bool _visible(Row row, AppUser user) {
    switch (_name) {
      case 'appointments':
        return switch (user.role) {
          Role.admin => true,
          Role.client => row['client'] == user.clientId,
          Role.master => row['master'] == user.masterId,
        };
      case 'clients':
        return user.role != Role.client || row['id'] == user.clientId;
      case 'client_cards':
        return user.role == Role.admin ||
            (user.role == Role.client && row['client'] == user.clientId);
      default:
        return true;
    }
  }

  AppUser _user() {
    final user = _session();
    if (user == null) throw const UnauthorizedException();
    return user;
  }

  void _authorizeWrite(AppUser user, String action, {Row? row, Row? body}) {
    if (user.role == Role.admin) return;
    final own = row != null && _visible(row, user);
    if (_name == 'appointments') {
      if (action == 'create' &&
          user.role == Role.client &&
          body?['client'] == user.clientId) {
        return;
      }
      if (action == 'update' && own) {
        if (user.role == Role.master) return;
        if (user.role == Role.client && body?['status'] == 'cancelled') {
          return;
        }
      }
    }
    if (_name == 'reviews' &&
        action == 'create' &&
        user.role == Role.client &&
        body?['client'] == user.clientId) {
      return;
    }
    throw const ForbiddenException();
  }

  Map<String, dynamic> _json(Row row) {
    final expand = <String, Object?>{};
    for (final f in schema.relationFields) {
      final target = f.target!;
      final targetTable = _db.table(target);
      if (f.kind == FieldKind.relation) {
        final id = '${row[f.key] ?? ''}';
        final found = targetTable.where((r) => r['id'] == id).firstOrNull;
        if (found != null) expand[f.key] = found;
      } else {
        final ids = row[f.key] is List
            ? [for (final v in row[f.key] as List) '$v']
            : const <String>[];
        expand[f.key] = [
          for (final id in ids)
            ...targetTable.where((r) => r['id'] == id).take(1),
        ];
      }
    }
    return {...row, 'expand': expand};
  }

  Rec _rec(Row row) => schema.parse(_json(row), schemaFor);

  bool _matches(Row row, RecQuery query) {
    if (!query.includeDeleted && '${row['deletedAt'] ?? ''}'.isNotEmpty) {
      return false;
    }
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty && schema.searchFields.isNotEmpty) {
      final hit = schema.searchFields.any(
        (f) => '${row[f] ?? ''}'.toLowerCase().contains(search),
      );
      if (!hit) return false;
    }
    for (final def in schema.filters) {
      final value = query.filters[def.param];
      if (value == null || value.isEmpty) continue;
      if (!_passes(row, def, value)) return false;
    }
    return true;
  }

  bool _passes(Row row, FilterDef def, String value) {
    final raw = row[def.field];
    switch (def.type) {
      case FilterType.refEquals:
      case FilterType.optionEquals:
        return '$raw' == value;
      case FilterType.refContains:
        return raw is List && raw.map((e) => '$e').contains(value);
      case FilterType.numMin:
        final n = asNum(raw);
        return n != null && n >= num.parse(value);
      case FilterType.numMax:
        final n = asNum(raw);
        return n != null && n <= num.parse(value);
      case FilterType.dateFrom:
      case FilterType.dateTo:
        final moment = asDate(raw);
        if (moment == null) return false;
        final day = DateTime.parse(value);
        final isDateField = schema.field(def.field)?.kind == FieldKind.date;
        final from = def.type == FilterType.dateFrom;
        if (isDateField) {
          final utc = moment.toUtc();
          final cell = DateTime.utc(utc.year, utc.month, utc.day);
          final limit = DateTime.utc(day.year, day.month, day.day);
          return from ? !cell.isBefore(limit) : !cell.isAfter(limit);
        }
        final local = moment.toLocal();
        final limit = from
            ? DateTime(day.year, day.month, day.day)
            : DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
        return from ? !local.isBefore(limit) : !local.isAfter(limit);
    }
  }

  int _compare(Row a, Row b, String field) {
    final x = a[field];
    final y = b[field];
    if (x is num && y is num) return x.compareTo(y);
    return '${x ?? ''}'.toLowerCase().compareTo('${y ?? ''}'.toLowerCase());
  }

  @override
  Future<PageResult<Rec>> find(RecQuery query, {RequestToken? token}) async {
    await _wait();
    if (token != null && token.isCancelled) {
      throw const RequestCancelledException();
    }
    final user = _user();
    final rows = _db
        .table(_name)
        .where((r) => _visible(r, user) && _matches(r, query))
        .toList();
    rows.sort((a, b) {
      final c = _compare(a, b, query.sortField);
      return query.sortAscending ? c : -c;
    });
    final total = rows.length;
    final from = (query.page - 1) * query.size;
    final slice = rows.skip(from).take(query.size).toList();
    return PageResult<Rec>(
      items: [for (final row in slice) _rec(row)],
      page: query.page,
      size: query.size,
      total: total,
    );
  }

  @override
  Future<Rec?> findById(String id) async {
    await _wait();
    final user = _user();
    final row = _db.find(_name, id);
    if (row == null || !_visible(row, user)) return null;
    return _rec(row);
  }

  Map<String, String> _validateBody(Row body, {String? selfId}) {
    final errors = <String, String>{};
    for (final f in schema.fields) {
      if (!body.containsKey(f.key) && selfId != null) continue;
      final raw = body[f.key];
      Object? value = raw;
      if (f.kind == FieldKind.date || f.kind == FieldKind.dateTime) {
        value = asDate(raw);
      }
      final message = schema.validateField(
        f,
        f.isNumeric ? '${raw ?? ''}' : value,
      );
      if (message != null) errors[f.key] = message;
      if (f.isRelation && message == null) {
        final ids = f.kind == FieldKind.relation
            ? ['${raw ?? ''}'].where((e) => e.isNotEmpty)
            : [for (final v in (raw as List? ?? const [])) '$v'];
        for (final id in ids) {
          if (_db.find(f.target!, id) == null) {
            errors[f.key] = 'Связанная запись не найдена';
          }
        }
      }
    }
    for (final group in _uniqueKeys[_name] ?? const <List<String>>[]) {
      if (group.any((k) => errors.containsKey(k))) continue;
      final taken = _db
          .table(_name)
          .any(
            (r) =>
                r['id'] != selfId &&
                group.every((k) => '${r[k] ?? ''}' == '${body[k] ?? ''}'),
          );
      if (taken) {
        errors[group.first] = group.length == 1
            ? 'Такое значение уже используется'
            : 'Такая комбинация уже существует';
      }
    }
    if (errors.isEmpty && schema.extraValidate != null) {
      final typed = <String, Object?>{
        for (final f in schema.fields)
          f.key: (f.kind == FieldKind.date || f.kind == FieldKind.dateTime)
              ? asDate(body[f.key])?.toLocal()
              : body[f.key],
      };
      errors.addAll(schema.extraValidate!(typed));
    }
    return errors;
  }

  void _checkAppointment(Row merged, String? selfId) {
    if (merged['status'] == 'cancelled') return;
    final master = '${merged['master']}';
    final start = asDate(merged['startsAt'])?.toLocal();
    final end = asDate(merged['endsAt'])?.toLocal();
    if (start == null || end == null) return;
    final schedule = _db
        .table('schedules')
        .where(
          (r) =>
              r['master'] == master &&
              r['weekday'] == weekdayKey(start) &&
              '${r['deletedAt'] ?? ''}'.isEmpty,
        );
    final shift = schedule.isEmpty
        ? null
        : Shift(
            '${schedule.first['startTime']}',
            '${schedule.first['endTime']}',
          );
    final busy = <TimeRange>[
      for (final r in _db.table('appointments'))
        if (r['id'] != selfId &&
            r['master'] == master &&
            r['status'] != 'cancelled' &&
            '${r['deletedAt'] ?? ''}'.isEmpty)
          TimeRange(
            asDate(r['startsAt'])!.toLocal(),
            asDate(r['endsAt'])!.toLocal(),
          ),
    ];
    final message = checkBooking(
      wanted: TimeRange(start, end),
      shift: shift,
      busy: busy,
    );
    if (message != null) throw ConflictException(message);
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<Rec> create(Map<String, Object?> values) async {
    await _wait();
    final user = _user();
    final body = schema.toBody(values);
    _authorizeWrite(user, 'create', body: body);
    final errors = _validateBody(body);
    if (_name == 'reviews' && !errors.containsKey('appointment')) {
      final appointment = _db.find('appointments', '${body['appointment']}');
      if (appointment != null && appointment['status'] != 'done') {
        errors['appointment'] =
            'Отзыв можно оставить только о выполненной записи';
      }
    }
    if (errors.isNotEmpty) {
      throw ValidationException('Проверьте введённые данные.', errors);
    }
    final row = <String, Object?>{
      'id': _db.newId(),
      'created': _now(),
      'updated': _now(),
      'deletedAt': '',
      ...body,
    };
    if (_name == 'appointments') _checkAppointment(row, null);
    _db.table(_name).add(row);
    _db.save();
    return _rec(row);
  }

  @override
  Future<Rec> update(String id, Map<String, Object?> values) async {
    await _wait();
    final user = _user();
    final row = _db.find(_name, id);
    if (row == null) throw const NotFoundException();
    final body = schema.toBody(values);
    _authorizeWrite(user, 'update', row: row, body: body);
    final merged = {...row, ...body};
    final errors = _validateBody(merged, selfId: id);
    if (errors.isNotEmpty) {
      throw ValidationException('Проверьте введённые данные.', errors);
    }
    if (_name == 'appointments') _checkAppointment(merged, id);
    row
      ..addAll(body)
      ..['updated'] = _now();
    _db.save();
    return _rec(row);
  }

  Row _writable(String id) {
    final user = _user();
    if (user.role != Role.admin) throw const ForbiddenException();
    final row = _db.find(_name, id);
    if (row == null) throw const NotFoundException();
    return row;
  }

  @override
  Future<void> softDelete(String id) async {
    await _wait();
    final row = _writable(id);
    row['deletedAt'] = _now();
    row['updated'] = _now();
    _db.save();
  }

  @override
  Future<void> restore(String id) async {
    await _wait();
    final row = _writable(id);
    row['deletedAt'] = '';
    row['updated'] = _now();
    _db.save();
  }

  @override
  Future<void> hardDelete(String id) async {
    await _wait();
    final row = _writable(id);
    for (final other in allSchemas) {
      for (final f in other.relationFields) {
        if (f.target != _name) continue;
        final used = _db.table(other.collection).any((r) {
          final v = r[f.key];
          return v == id || (v is List && v.contains(id));
        });
        if (used) {
          throw const ConflictException(
            'Запись используется в других данных, удалить её нельзя.',
          );
        }
      }
    }
    _db.table(_name).remove(row);
    _db.save();
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var done = 0;
    for (final id in ids) {
      await softDelete(id);
      done++;
    }
    return done;
  }
}

SalonRepositories createLocalRepositories(
  LocalDatabase db,
  AppUser? Function() session, {
  Duration latency = Duration.zero,
}) => SalonRepositories({
  for (final schema in allSchemas)
    schema.collection: LocalRepository(db, schema, session, latency: latency),
});
