import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/permission.dart';
import '../core/layout.dart';
import '../models/rec.dart';
import '../models/rec_query.dart';
import '../repositories/record_repository.dart';
import '../schema/entity_schema.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/card_grid.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_filters.dart';
import '../widgets/entity_table.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/salon_scaffold.dart';
import 'review_dialog.dart';

enum ListMode { manage, ownClient, ownMaster }

extension ListModeInfo on ListMode {
  String? get basePath => switch (this) {
    ListMode.manage => null,
    ListMode.ownClient => '/my-appointments',
    ListMode.ownMaster => '/my-schedule',
  };

  String get sectionId => switch (this) {
    ListMode.manage => '',
    ListMode.ownClient => 'my-appointments',
    ListMode.ownMaster => 'my-schedule',
  };

  String? get title => switch (this) {
    ListMode.manage => null,
    ListMode.ownClient => 'Мои записи',
    ListMode.ownMaster => 'Моё расписание',
  };
}

Widget _clip(String text, {double width = 220}) => ConstrainedBox(
  constraints: BoxConstraints(maxWidth: width),
  child: Text(text, overflow: TextOverflow.ellipsis),
);

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({
    super.key,
    required this.schema,
    required this.uri,
    this.mode = ListMode.manage,
  });

  final EntitySchema schema;
  final Uri uri;
  final ListMode mode;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  late final EntityListNotifier _notifier;

  EntitySchema get schema => widget.schema;
  String get _basePath => widget.mode.basePath ?? schema.path;

  Set<String> get _hidden => switch (widget.mode) {
    ListMode.manage => const {},
    ListMode.ownClient => const {'client'},
    ListMode.ownMaster => const {'master'},
  };

  RecQuery _parse() => RecQuery.fromParams(schema, widget.uri.queryParameters);

  @override
  void initState() {
    super.initState();
    _notifier = EntityListNotifier(
      repository: context.read<SalonRepositories>().of(schema.collection),
      initialQuery: _parse(),
      events: context.read<CatalogEvents>(),
    )..load();
  }

  @override
  void didUpdateWidget(covariant EntityListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) _notifier.applyQuery(_parse());
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  void _go(RecQuery next) => context.go(next.toUri(_basePath).toString());

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _delete(Rec item) async {
    final ok = await confirmAction(
      context,
      title: 'Удалить ${schema.accusative}?',
      message:
          '«${schema.title(item)}» будет скрыта из списка. '
          'Администратор сможет восстановить запись.',
      confirmLabel: 'Удалить',
    );
    if (ok) await _notifier.softDelete(item.id);
  }

  Future<void> _purge(Rec item) async {
    final ok = await confirmAction(
      context,
      title: 'Удалить навсегда?',
      message:
          'Запись «${schema.title(item)}» будет удалена без возможности восстановления.',
      confirmLabel: 'Удалить навсегда',
    );
    if (ok) await _notifier.hardDelete(item.id);
  }

  Future<void> _deleteSelected() async {
    final count = _notifier.selected.length;
    final ok = await confirmAction(
      context,
      title: 'Удалить выбранные записи?',
      message: 'Будет удалено записей: $count.',
      confirmLabel: 'Удалить',
    );
    if (ok) await _notifier.deleteSelected();
  }

  Future<void> _setStatus(Rec item, String status, String done) async {
    final ok = await _notifier.update(item.id, {'status': status});
    if (ok && mounted) _snack(done);
  }

  Future<void> _cancel(Rec item) async {
    final ok = await confirmAction(
      context,
      title: 'Отменить запись?',
      message: '«${schema.title(item)}» будет отменена.',
      confirmLabel: 'Отменить запись',
    );
    if (ok) await _setStatus(item, 'cancelled', 'Запись отменена');
  }

  Future<void> _review(Rec item) async {
    final saved = await showReviewDialog(context, appointment: item);
    if (saved && mounted) _snack('Спасибо за отзыв!');
  }

  List<Widget> _actions(Rec item, AuthNotifier auth) {
    IconButton button(
      String key,
      String tooltip,
      IconData icon,
      VoidCallback? onPressed,
    ) => IconButton(
      key: ValueKey('$key-${item.id}'),
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: _notifier.busy ? null : onPressed,
    );

    switch (widget.mode) {
      case ListMode.ownClient:
        final status = item.text('status');
        final start = item.date('startsAt');
        final future = start != null && start.isAfter(DateTime.now());
        return [
          if (future && (status == 'new' || status == 'confirmed'))
            button(
              'cancel',
              'Отменить запись',
              Icons.event_busy_outlined,
              () => _cancel(item),
            ),
          if (status == 'done' && auth.can(Permission.writeReview))
            button(
              'review',
              'Оставить отзыв',
              Icons.star_outline,
              () => _review(item),
            ),
        ];
      case ListMode.ownMaster:
        final status = item.text('status');
        return [
          if (status == 'new')
            button(
              'confirm',
              'Подтвердить запись',
              Icons.check_outlined,
              () => _setStatus(item, 'confirmed', 'Запись подтверждена'),
            ),
          if (status == 'new' || status == 'confirmed')
            button(
              'done',
              'Отметить выполненной',
              Icons.task_alt_outlined,
              () => _setStatus(item, 'done', 'Запись выполнена'),
            ),
          if (status == 'new' || status == 'confirmed')
            button(
              'cancel',
              'Отменить запись',
              Icons.event_busy_outlined,
              () => _cancel(item),
            ),
        ];
      case ListMode.manage:
        final canEdit = auth.can(Permission.editData);
        final canPurge = auth.can(Permission.purgeData);
        return [
          button(
            'open',
            'Открыть',
            Icons.visibility_outlined,
            () => context.push('${schema.path}/${item.id}'),
          ),
          if (canEdit && !item.isDeleted)
            button(
              'edit',
              'Изменить',
              Icons.edit_outlined,
              () => context.push('${schema.path}/${item.id}/edit'),
            ),
          if (canEdit && !item.isDeleted)
            button(
              'delete',
              'Удалить',
              Icons.delete_outline,
              () => _delete(item),
            ),
          if (canPurge && item.isDeleted)
            button(
              'restore',
              'Восстановить',
              Icons.restore_from_trash_outlined,
              () => _notifier.restore(item.id),
            ),
          if (canPurge && item.isDeleted)
            button(
              'purge',
              'Удалить навсегда',
              Icons.delete_forever_outlined,
              () => _purge(item),
            ),
        ];
    }
  }

  List<TableColumnSpec<Rec>> _columns() {
    final fields = [
      for (final f in schema.fields)
        if (f.inList && !_hidden.contains(f.key)) f,
    ];
    return [
      for (var i = 0; i < fields.length; i++)
        TableColumnSpec<Rec>(
          label: fields[i].label,
          sortField: fields[i].sortable ? fields[i].key : null,
          numeric: fields[i].isNumeric,
          optional: fields.length > 5 && i >= 5,
          build: (r) => _clip(schema.format(r, fields[i])),
        ),
    ];
  }

  Widget _card(Rec item, AuthNotifier auth) {
    final fields = [
      for (final f in schema.fields)
        if (f.inList && !_hidden.contains(f.key)) f,
    ];
    final scheme = Theme.of(context).colorScheme;
    final actions = _actions(item, auth);
    return Card(
      key: ValueKey('card-${item.id}'),
      color: item.isDeleted ? scheme.surfaceContainerHighest : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.mode == ListMode.manage
            ? () => context.push('${schema.path}/${item.id}')
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schema.title(item),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  decoration: item.isDeleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (item.isDeleted)
                Text('Удалено', style: TextStyle(color: scheme.error)),
              const SizedBox(height: 4),
              for (final f in fields.skip(1).take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${f.label}: ',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        TextSpan(text: schema.format(item, f)),
                      ],
                    ),
                  ),
                ),
              if (actions.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AuthNotifier auth, ScreenSize size) {
    final n = _notifier;
    final query = n.query;
    switch (n.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingPanel();
      case LoadStatus.error:
        return ErrorPanel(
          message: n.error ?? 'Не удалось загрузить список.',
          onRetry: n.load,
        );
      case LoadStatus.success:
        final page = n.result;
        if (page.isEmpty) {
          return EmptyPanel(
            title: query.hasFilters ? 'Ничего не найдено' : 'Пока нет записей',
            message: query.hasFilters
                ? 'Измените условия поиска или сбросьте фильтры.'
                : null,
            actionLabel: query.hasFilters ? 'Сбросить фильтры' : null,
            onAction: query.hasFilters ? () => _go(query.reset()) : null,
          );
        }
        final canSelect =
            widget.mode == ListMode.manage && auth.can(Permission.editData);
        final table = size == ScreenSize.expanded;
        return Column(
          children: [
            Expanded(
              child: table
                  ? EntityTable<Rec>(
                      columns: _columns(),
                      items: page.items,
                      selected: canSelect ? n.selected : const {},
                      onToggleSelect: canSelect ? n.toggleSelection : null,
                      onSelectAll: canSelect ? n.selectAll : null,
                      sortField: query.sortField,
                      sortAscending: query.sortAscending,
                      onSort: (field) => _go(
                        query.copyWith(
                          sortField: field,
                          sortAscending: query.sortField == field
                              ? !query.sortAscending
                              : true,
                        ),
                      ),
                      onOpen: widget.mode == ListMode.manage
                          ? (r) => context.push('${schema.path}/${r.id}')
                          : null,
                      actions: (r) => _actions(r, auth),
                    )
                  : CardGrid<Rec>(
                      items: page.items,
                      columns: size.cardColumns,
                      itemBuilder: (context, item) => _card(item, auth),
                    ),
            ),
            PaginationBar(
              page: page,
              size: query.size,
              enabled: !n.busy,
              onPage: (p) => _go(query.withCommon(page: p)),
              onSize: (s) => _go(query.withCommon(size: s, page: 1)),
            ),
          ],
        );
    }
  }

  Widget _sortBox(RecQuery query) {
    final sortable = [
      for (final f in schema.fields)
        if (f.sortable) f,
    ];
    if (sortable.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('sort-field'),
            initialValue: sortable.any((f) => f.key == query.sortField)
                ? query.sortField
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Сортировка'),
            items: [
              for (final f in sortable)
                DropdownMenuItem(value: f.key, child: Text(f.label)),
            ],
            onChanged: (v) => v == null
                ? null
                : _go(query.copyWith(sortField: v, sortAscending: true)),
          ),
        ),
        IconButton(
          key: const ValueKey('sort-direction'),
          tooltip: query.sortAscending ? 'По возрастанию' : 'По убыванию',
          icon: Icon(
            query.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
          onPressed: () =>
              _go(query.copyWith(sortAscending: !query.sortAscending)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final size = ScreenSize.of(context);
    final canCreate =
        widget.mode == ListMode.manage && auth.can(Permission.editData);
    final compact = size != ScreenSize.expanded;

    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final query = _notifier.query;
        final filters = EntityFilters(
          schema: schema,
          query: query,
          onChange: _go,
          hidden: _hidden,
          allowDeleted:
              widget.mode == ListMode.manage && auth.can(Permission.purgeData),
        );
        final filterCard = Card(
          child: compact
              ? ExpansionTile(
                  key: const ValueKey('filters-panel'),
                  title: const Text('Поиск, фильтры и сортировка'),
                  leading: const Icon(Icons.tune),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    filters,
                    const SizedBox(height: 12),
                    _sortBox(query),
                  ],
                )
              : Padding(padding: const EdgeInsets.all(16), child: filters),
        );
        return SalonScaffold(
          title: widget.mode.title ?? schema.titlePlural,
          subtitle: widget.mode == ListMode.manage
              ? 'Найдите запись, отфильтруйте список или откройте карточку'
              : null,
          section: widget.mode == ListMode.manage
              ? schema.section
              : widget.mode.sectionId,
          actions: [
            if (canCreate && size.isCompact)
              IconButton.filled(
                key: const ValueKey('create-button'),
                tooltip: 'Добавить',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: () => context.push('${schema.path}/new'),
                icon: const Icon(Icons.add),
              )
            else if (canCreate)
              FilledButton.icon(
                key: const ValueKey('create-button'),
                onPressed: () => context.push('${schema.path}/new'),
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filterCard,
              const SizedBox(height: 12),
              if (_notifier.operationError != null)
                OperationBanner(
                  message: _notifier.operationError!,
                  onClose: _notifier.clearOperationError,
                ),
              if (_notifier.hasSelection)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text('Выбрано: ${_notifier.selected.length}'),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        key: const ValueKey('delete-selected'),
                        onPressed: _notifier.busy ? null : _deleteSelected,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Удалить выбранные'),
                      ),
                      TextButton(
                        onPressed: _notifier.clearSelection,
                        child: const Text('Снять выбор'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: size == ScreenSize.expanded
                    ? Card(
                        clipBehavior: Clip.antiAlias,
                        child: _content(auth, size),
                      )
                    : _content(auth, size),
              ),
            ],
          ),
        );
      },
    );
  }
}
