import '../models/rec.dart';

class BarItem {
  const BarItem(this.label, this.value);

  final String label;
  final num value;
}

class SalonStats {
  const SalonStats({
    required this.count,
    required this.revenue,
    required this.byMaster,
    required this.byService,
  });

  final int count;
  final num revenue;
  final List<BarItem> byMaster;
  final List<BarItem> byService;

  num get average => count == 0 ? 0 : revenue / count;

  static const empty = SalonStats(
    count: 0,
    revenue: 0,
    byMaster: [],
    byService: [],
  );
}

SalonStats computeStats(Iterable<Rec> doneAppointments) {
  var count = 0;
  num revenue = 0;
  final masters = <String, num>{};
  final services = <String, num>{};
  for (final rec in doneAppointments) {
    if (rec.text('status') != 'done' || rec.isDeleted) continue;
    count++;
    final price = rec.number('totalPrice') ?? 0;
    revenue += price;
    final master = rec.labelOf('master');
    final masterKey = master.isEmpty ? rec.ref('master') : master;
    masters[masterKey] = (masters[masterKey] ?? 0) + price;
    for (final name in rec.labels['services'] ?? const <String>[]) {
      services[name] = (services[name] ?? 0) + 1;
    }
  }
  List<BarItem> sorted(Map<String, num> source) =>
      [for (final e in source.entries) BarItem(e.key, e.value)]
        ..sort((a, b) => b.value.compareTo(a.value));
  return SalonStats(
    count: count,
    revenue: revenue,
    byMaster: sorted(masters),
    byService: sorted(services),
  );
}
