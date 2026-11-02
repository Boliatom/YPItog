String _two(int n) => n.toString().padLeft(2, '0');

String formatDay(DateTime? date) {
  if (date == null) return '—';
  final d = date.toUtc();
  return '${_two(d.day)}.${_two(d.month)}.${d.year}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  return '${_two(d.day)}.${_two(d.month)}.${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

DateTime dayToUtc(DateTime picked, {bool clampToNow = false}) {
  final utc = DateTime.utc(picked.year, picked.month, picked.day);
  if (clampToNow) {
    final now = DateTime.now().toUtc();
    if (utc.isAfter(now)) return now;
  }
  return utc;
}

DateTime utcDayToLocal(DateTime date) {
  final d = date.toUtc();
  return DateTime(d.year, d.month, d.day);
}
