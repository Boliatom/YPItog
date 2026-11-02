import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/date_format.dart';
import '../core/layout.dart';
import '../domain/stats.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../repositories/record_repository.dart';
import '../schema/entity_schema.dart';
import '../schema/schemas.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  late DateTime _to = DateTime.now();
  late Future<SalonStats> _future = _load();

  Future<SalonStats> _load() async {
    final repo = context.read<SalonRepositories>().appointments;
    final items = <Rec>[];
    var page = 1;
    while (true) {
      final chunk = await repo.find(
        RecQuery(
          schema: appointmentsSchema,
          filters: {
            'status': 'done',
            'from': _isoDay(_from),
            'to': _isoDay(_to),
          },
          page: page,
          size: 50,
        ),
      );
      items.addAll(chunk.items);
      if (!chunk.hasNext || page >= 20) break;
      page++;
    }
    return computeStats(items);
  }

  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
      _future = _load();
    });
  }

  String _day(DateTime d) => formatDay(DateTime.utc(d.year, d.month, d.day));

  @override
  Widget build(BuildContext context) {
    final size = ScreenSize.of(context);
    return SalonScaffold(
      title: 'Отчёт по выручке',
      subtitle: 'Выполненные записи за выбранный период',
      section: 'stats',
      body: ListView(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('stats-from'),
                onPressed: () => _pick(true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('С ${_day(_from)}'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('stats-to'),
                onPressed: () => _pick(false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('По ${_day(_to)}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<SalonStats>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(height: 240, child: LoadingPanel());
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return SizedBox(
                  height: 280,
                  child: ErrorPanel(
                    message: error is ApiException
                        ? error.message
                        : 'Не удалось построить отчёт.',
                    onRetry: () => setState(() => _future = _load()),
                  ),
                );
              }
              final stats = snapshot.data!;
              if (stats.count == 0) {
                return const SizedBox(
                  height: 280,
                  child: EmptyPanel(
                    title: 'Нет выполненных записей',
                    message: 'За выбранный период выполненных записей нет.',
                    icon: Icons.insights_outlined,
                  ),
                );
              }
              final cards = [
                _Metric('Выполнено записей', '${stats.count}'),
                _Metric('Выручка', '${numText(stats.revenue)} ₽'),
                _Metric('Средний чек', '${numText(stats.average.round())} ₽'),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final m in cards)
                        SizedBox(
                          width: size.isCompact ? double.infinity : 220,
                          child: m,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BarCard(
                    key: const ValueKey('stats-masters'),
                    title: 'Выручка по мастерам, ₽',
                    items: stats.byMaster,
                  ),
                  const SizedBox(height: 12),
                  _BarCard(
                    key: const ValueKey('stats-services'),
                    title: 'Популярность услуг, раз',
                    items: stats.byService.take(8).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label),
        ],
      ),
    ),
  );
}

class _BarCard extends StatelessWidget {
  const _BarCard({super.key, required this.title, required this.items});

  final String title;
  final List<BarItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = items.fold<num>(0, (a, b) => b.value > a ? b.value : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(numText(item.value)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: maxValue == 0
                            ? 0
                            : (item.value / maxValue).toDouble(),
                        minHeight: 12,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
