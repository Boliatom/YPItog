import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/permission.dart';
import '../core/api_exceptions.dart';
import '../core/date_format.dart';
import '../core/layout.dart';
import '../core/navigation.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../repositories/record_repository.dart';
import '../schema/entity_schema.dart';
import '../schema/schemas.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart' show LoadStatus;
import '../widgets/confirmation_dialog.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

class _Related {
  const _Related(this.label, this.value);

  final String label;
  final String value;
}

class EntityDetailScreen extends StatefulWidget {
  const EntityDetailScreen({super.key, required this.schema, required this.id});

  final EntitySchema schema;
  final String id;

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  Rec? _rec;
  List<_Related> _related = const [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  EntitySchema get schema => widget.schema;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    final repos = context.read<SalonRepositories>();
    try {
      final rec = await repos.of(schema.collection).findById(widget.id);
      if (rec == null) throw const NotFoundException();
      final related = await _loadRelated(repos, rec);
      if (!mounted) return;
      setState(() {
        _rec = rec;
        _related = related;
        _status = LoadStatus.success;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _status = LoadStatus.error;
          _error = e.message;
        });
      }
    }
  }

  Future<List<_Related>> _loadRelated(SalonRepositories repos, Rec rec) async {
    try {
      switch (schema.collection) {
        case 'clients':
          final cards = await repos.cards.find(
            RecQuery(schema: cardsSchema, filters: {'client': rec.id}),
          );
          final visits = await repos.appointments.find(
            RecQuery(
              schema: appointmentsSchema,
              filters: {'client': rec.id},
              size: 10,
            ),
          );
          final card = cards.items.firstOrNull;
          return [
            _Related(
              'Карта клиента',
              card == null
                  ? 'Не выдана'
                  : '${card.text('number')}, скидка ${card.integer('discountPercent') ?? 0}%, '
                        'баллов: ${card.integer('bonusPoints') ?? 0}',
            ),
            _Related('Записей у клиента', '${visits.total}'),
          ];
        case 'masters':
          final reviews = await repos.reviews.find(
            RecQuery(
              schema: reviewsSchema,
              filters: {'master': rec.id},
              size: 50,
            ),
          );
          final ratings = [
            for (final r in reviews.items)
              if (r.integer('rating') != null) r.integer('rating')!,
          ];
          final average = ratings.isEmpty
              ? 'Пока нет оценок'
              : '${(ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1)} из 5 '
                    '(отзывов: ${reviews.total})';
          return [_Related('Средняя оценка', average)];
        case 'appointments':
          final reviews = await repos.reviews.find(
            RecQuery(schema: reviewsSchema, search: ''),
          );
          final mine = reviews.items
              .where((r) => r.ref('appointment') == rec.id)
              .firstOrNull;
          return [
            _Related(
              'Отзыв о визите',
              mine == null
                  ? 'Нет'
                  : '${mine.integer('rating')} из 5. ${mine.text('text')}',
            ),
          ];
        case 'service_categories':
          final services = await repos.services.find(
            RecQuery(schema: servicesSchema, filters: {'category': rec.id}),
          );
          return [_Related('Услуг в категории', '${services.total}')];
      }
    } on ApiException {
      return const [];
    }
    return const [];
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Удалить ${schema.accusative}?',
      message: '«${schema.title(_rec!)}» будет скрыта из списка.',
      confirmLabel: 'Удалить',
    );
    if (!ok || !mounted) return;
    try {
      await context
          .read<SalonRepositories>()
          .of(schema.collection)
          .softDelete(widget.id);
      if (mounted) popOrGo(context, schema.path);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final rec = _rec;
    final canEdit = auth.can(Permission.editData);
    return SalonScaffold(
      title: rec == null ? schema.titleSingular : schema.title(rec),
      subtitle: schema.titleSingular,
      section: schema.section,
      leading: IconButton(
        key: const ValueKey('detail-back'),
        tooltip: 'Назад',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => popOrGo(context, schema.path),
      ),
      actions: [
        if (rec != null && canEdit && !rec.isDeleted) ...[
          OutlinedButton.icon(
            key: const ValueKey('detail-edit'),
            onPressed: () => context.push('${schema.path}/${rec.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Изменить'),
          ),
          FilledButton.icon(
            key: const ValueKey('detail-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить'),
          ),
        ],
      ],
      body: switch (_status) {
        LoadStatus.idle || LoadStatus.loading => const LoadingPanel(),
        LoadStatus.error => ErrorPanel(
          message: _error ?? 'Неизвестная ошибка.',
          onRetry: _load,
        ),
        LoadStatus.success => _details(context, rec!),
      },
    );
  }

  Widget _details(BuildContext context, Rec rec) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <_Related>[
      for (final f in schema.fields) _Related(f.label, schema.format(rec, f)),
      ..._related,
      _Related('Создано', formatDateTime(rec.created)),
      _Related('Изменено', formatDateTime(rec.updated)),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxFormWidth),
        child: ListView(
          children: [
            if (rec.isDeleted)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Запись удалена ${formatDateTime(rec.deletedAt)}',
                      key: const ValueKey('detail-deleted'),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (final row in rows)
                      ListTile(
                        dense: true,
                        title: Text(
                          row.label,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        subtitle: Text(
                          row.value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
