int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

int asInt(Object? value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;

String asString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return value is String ? value : value.toString();
}

String? asStringOrNull(Object? value) {
  final text = asString(value).trim();
  return text.isEmpty ? null : text;
}

DateTime? asDate(Object? value) {
  if (value is DateTime) return value;
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim());
}

List<int> asIntList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (asIntOrNull(item) != null) asIntOrNull(item)!,
  ];
}

Map<String, dynamic>? asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return null;
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (asMap(item) != null) asMap(item)!,
  ];
}

num? asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}
