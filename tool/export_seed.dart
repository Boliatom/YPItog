import 'dart:convert';
import 'dart:io';

import 'package:salon_app/repositories/seed_data.dart';

void main(List<String> args) {
  final tables = buildSeed(DateTime.now());
  final out = args.isNotEmpty ? File(args.first) : null;
  final text = const JsonEncoder.withIndent('  ').convert(tables);
  if (out == null) {
    stdout.writeln(text);
  } else {
    out.writeAsStringSync(text);
  }
}
