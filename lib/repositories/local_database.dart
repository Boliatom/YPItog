import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'seed_data.dart';

class LocalDatabase {
  LocalDatabase._(this._tables, this._prefs, {this.notice});

  static const storageKey = 'salon.db';

  final Tables _tables;
  final SharedPreferences? _prefs;
  final String? notice;
  final Random _random = Random();

  factory LocalDatabase.seeded({SharedPreferences? prefs, DateTime? now}) =>
      LocalDatabase._(buildSeed(now ?? DateTime.now()), prefs);

  factory LocalDatabase.restore(SharedPreferences prefs, {DateTime? now}) {
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final tables = <String, List<Row>>{
          for (final entry in decoded.entries)
            entry.key: [
              for (final row in entry.value as List)
                Map<String, Object?>.from(row as Map),
            ],
        };
        return LocalDatabase._(tables, prefs);
      } catch (_) {
        final db = LocalDatabase._(
          buildSeed(now ?? DateTime.now()),
          prefs,
          notice:
              'Сохранённые данные повреждены, загружены учебные данные заново.',
        );
        db.save();
        return db;
      }
    }
    final db = LocalDatabase._(buildSeed(now ?? DateTime.now()), prefs);
    db.save();
    return db;
  }

  List<Row> table(String name) => _tables.putIfAbsent(name, () => <Row>[]);

  Row? find(String name, String id) {
    for (final row in table(name)) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  String newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes([
      for (var i = 0; i < 15; i++)
        alphabet.codeUnitAt(_random.nextInt(alphabet.length)),
    ]);
  }

  void save() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(
      prefs.setString(storageKey, jsonEncode(_tables)).catchError((_) => false),
    );
  }
}
