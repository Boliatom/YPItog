import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/role.dart';
import '../core/api_exceptions.dart';
import '../core/date_format.dart';
import '../core/layout.dart';
import '../models/rec_query.dart';
import '../repositories/record_repository.dart';
import '../schema/schemas.dart';
import '../state/auth_notifier.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _Tile {
  const _Tile(this.label, this.value, this.icon, {this.route});

  final String label;
  final String value;
  final IconData icon;
  final String? route;
}

class _Overview {
  const _Overview({required this.tiles, this.lines = const [], this.heading});

  final List<_Tile> tiles;
  final List<String> lines;
  final String? heading;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_Overview> _future = _load();

  Future<_Overview> _load() async {
    final auth = context.read<AuthNotifier>();
    final repos = context.read<SalonRepositories>();
    final user = auth.user;
    final today = _isoDay(DateTime.now());
    switch (user?.role) {
      case Role.admin:
        final next = await repos.appointments.find(
          RecQuery(
            schema: appointmentsSchema,
            filters: {'from': today},
            sortField: 'startsAt',
            sortAscending: true,
            size: 8,
          ),
        );
        final all = await Future.wait([
          repos.appointments.find(
            RecQuery(
              schema: appointmentsSchema,
              filters: {'from': today, 'to': today},
            ),
          ),
          repos.appointments.find(
            RecQuery(schema: appointmentsSchema, filters: {'status': 'new'}),
          ),
          repos.clients.find(RecQuery(schema: clientsSchema)),
          repos.services.find(RecQuery(schema: servicesSchema)),
        ]);
        return _Overview(
          tiles: [
            _Tile(
              'Записей сегодня',
              '${all[0].total}',
              Icons.today_outlined,
              route: '/appointments?from=$today&to=$today',
            ),
            _Tile(
              'Новые записи',
              '${all[1].total}',
              Icons.mark_email_unread_outlined,
              route: '/appointments?status=new',
            ),
            _Tile(
              'Клиентов',
              '${all[2].total}',
              Icons.people_outline,
              route: '/clients',
            ),
            _Tile(
              'Услуг в каталоге',
              '${all[3].total}',
              Icons.spa_outlined,
              route: '/services',
            ),
          ],
          heading: 'Ближайшие записи салона',
          lines: [
            for (final r in next.items)
              if (r.text('status') != 'cancelled')
                '${formatDateTime(r.date('startsAt'))} · ${r.labelOf('master')} · '
                    '${r.labelOf('client')}',
          ],
        );
      case Role.master:
        final page = await repos.appointments.find(
          RecQuery(
            schema: appointmentsSchema,
            filters: {'from': today, 'to': today},
            sortField: 'startsAt',
            sortAscending: true,
          ),
        );
        return _Overview(
          heading: 'Записи на сегодня',
          tiles: [
            _Tile(
              'Записей сегодня',
              '${page.total}',
              Icons.today_outlined,
              route: '/my-schedule?from=$today&to=$today',
            ),
          ],
          lines: [
            for (final r in page.items)
              '${formatDateTime(r.date('startsAt')).substring(11)} · '
                  '${r.labelOf('client')} · ${r.labelOf('services')}',
          ],
        );
      case Role.client:
      case null:
        final clientId = user?.clientId ?? '';
        final results = await Future.wait([
          repos.appointments.find(
            RecQuery(
              schema: appointmentsSchema,
              filters: {'from': today},
              sortField: 'startsAt',
              sortAscending: true,
              size: 10,
            ),
          ),
          repos.cards.find(
            RecQuery(schema: cardsSchema, filters: {'client': clientId}),
          ),
        ]);
        final upcoming = [
          for (final r in results[0].items)
            if (r.text('status') != 'cancelled') r,
        ];
        final card = results[1].items.firstOrNull;
        return _Overview(
          heading: 'Ближайшие записи',
          tiles: [
            _Tile(
              'Предстоящих записей',
              '${upcoming.length}',
              Icons.event_available_outlined,
              route: '/my-appointments',
            ),
            _Tile(
              'Ваша скидка',
              '${card?.integer('discountPercent') ?? 0}%',
              Icons.percent,
            ),
            _Tile(
              'Бонусные баллы',
              '${card?.integer('bonusPoints') ?? 0}',
              Icons.stars_outlined,
            ),
          ],
          lines: [
            for (final r in upcoming.take(5))
              '${formatDateTime(r.date('startsAt'))} · ${r.labelOf('master')} · ${r.labelOf('services')}',
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final size = ScreenSize.of(context);
    return SalonScaffold(
      title: 'Главная',
      subtitle: user == null
          ? null
          : 'Здравствуйте, ${user.displayName}. Ваша роль: ${user.role.label}.',
      section: 'home',
      body: FutureBuilder<_Overview>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingPanel();
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ErrorPanel(
              message: error is ApiException
                  ? error.message
                  : 'Не удалось загрузить сводку.',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final overview = snapshot.data!;
          return ListView(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final tile in overview.tiles)
                    SizedBox(
                      width: size.isCompact ? double.infinity : 260,
                      child: Card(
                        key: ValueKey('tile-${tile.label}'),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: tile.route == null
                              ? null
                              : () => context.go(tile.route!),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(tile.icon, size: 36),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tile.value,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineMedium,
                                      ),
                                      Text(tile.label),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (overview.lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  overview.heading ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final line in overview.lines)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.schedule),
                          title: Text(line),
                        ),
                    ],
                  ),
                ),
              ] else if (overview.heading != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${overview.heading}: пока нет',
                  key: const ValueKey('dashboard-empty'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
