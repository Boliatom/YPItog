import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/permission.dart';
import '../core/app_theme.dart';
import '../core/layout.dart';
import '../state/auth_notifier.dart';
import 'connection_strip.dart';
import 'user_menu.dart';

class NavSection {
  const NavSection(
    this.id,
    this.location,
    this.label,
    this.icon, [
    this.permission,
    this.primary = false,
  ]);

  final String id;
  final String location;
  final String label;
  final IconData icon;
  final Permission? permission;

  final bool primary;

  bool visibleFor(AuthNotifier auth) =>
      permission == null ? auth.enabled : auth.can(permission!);
}

const navSections = [
  NavSection('home', '/', 'Главная', Icons.dashboard_outlined, null, true),
  NavSection(
    'book',
    '/book',
    'Записаться',
    Icons.event_available_outlined,
    Permission.bookOnline,
    true,
  ),
  NavSection(
    'my-appointments',
    '/my-appointments',
    'Мои записи',
    Icons.event_note_outlined,
    Permission.viewOwnAppointments,
    true,
  ),
  NavSection(
    'my-schedule',
    '/my-schedule',
    'Моё расписание',
    Icons.calendar_month_outlined,
    Permission.viewOwnSchedule,
    true,
  ),
  NavSection(
    'appointments',
    '/appointments',
    'Записи',
    Icons.event_note_outlined,
    Permission.viewAllAppointments,
    true,
  ),
  NavSection(
    'services',
    '/services',
    'Услуги',
    Icons.spa_outlined,
    Permission.viewCatalog,
    true,
  ),
  NavSection(
    'masters',
    '/masters',
    'Мастера',
    Icons.content_cut,
    Permission.viewCatalog,
  ),
  NavSection(
    'clients',
    '/clients',
    'Клиенты',
    Icons.people_outline,
    Permission.viewClients,
  ),
  NavSection(
    'reviews',
    '/reviews',
    'Отзывы',
    Icons.star_outline,
    Permission.viewCatalog,
  ),
  NavSection(
    'categories',
    '/categories',
    'Категории услуг',
    Icons.category_outlined,
    Permission.editData,
  ),
  NavSection(
    'cards',
    '/cards',
    'Карты клиентов',
    Icons.card_membership_outlined,
    Permission.editData,
  ),
  NavSection(
    'schedules',
    '/schedules',
    'График работы',
    Icons.schedule,
    Permission.editData,
  ),
  NavSection(
    'users',
    '/admin/users',
    'Пользователи',
    Icons.manage_accounts_outlined,
    Permission.manageUsers,
    true,
  ),
  NavSection(
    'stats',
    '/admin/stats',
    'Отчёт',
    Icons.bar_chart_outlined,
    Permission.viewStats,
    true,
  ),
];

class SalonScaffold extends StatelessWidget {
  const SalonScaffold({
    super.key,
    required this.title,
    required this.body,
    this.section,
    this.actions = const [],
    this.leading,
    this.subtitle,
    this.bare = false,
  });

  final String title;
  final Widget body;

  final String? section;
  final List<Widget> actions;
  final Widget? leading;

  final String? subtitle;

  final bool bare;

  @override
  Widget build(BuildContext context) {
    final size = ScreenSize.of(context);
    final wide = size == ScreenSize.expanded;
    final auth = context.watch<AuthNotifier>();
    final scheme = Theme.of(context).colorScheme;

    final sections = [
      for (final s in navSections)
        if (s.visibleFor(auth)) s,
    ];

    return Scaffold(
      appBar: wide
          ? _TopBar(sections: sections, selectedId: section)
          : AppBar(
              leading: leading,
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [...actions, const UserMenu(), const SizedBox(width: 8)],
            ),
      bottomNavigationBar: size.isCompact
          ? _BottomNav(sections: sections, selectedId: section)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const ConnectionStrip(),
            Expanded(
              child: wide
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: _ContentFrame(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PageHeader(
                              title: title,
                              subtitle: subtitle,
                              leading: leading,
                              actions: actions,
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: bare
                                  ? body
                                  : _Panel(
                                      color: Colors.transparent,
                                      child: body,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: size.isCompact
                          ? EdgeInsets.zero
                          : const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!size.isCompact) ...[
                            _Panel(
                              color: scheme.surface,
                              child: _SideNav(
                                sections: sections,
                                selectedId: section,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: _Panel(
                              color: Colors.transparent,
                              topOnly: size.isCompact,
                              child: _ContentFrame(child: body),
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

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.sections, required this.selectedId});

  final List<NavSection> sections;
  final String? selectedId;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.94),
      shape: Border(
        bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      child: SizedBox(
        height: 68,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const _Brand(extended: true),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _TopNav(sections: sections, selectedId: selectedId),
                  ),
                  const SizedBox(width: 8),
                  const UserMenu(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.sections, required this.selectedId});

  final List<NavSection> sections;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = [
      for (final s in sections)
        if (s.primary || s.id == selectedId) s,
    ];
    final more = [
      for (final s in sections)
        if (!shown.contains(s)) s,
    ];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            key: const ValueKey('main-nav'),
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final s in shown)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Semantics(
                    selected: s.id == selectedId,
                    child: Material(
                      color: s.id == selectedId
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('nav-${s.id}'),
                        onTap: () => context.go(s.location),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.icon,
                                size: 18,
                                color: s.id == selectedId
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                s.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: s.id == selectedId
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (more.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: PopupMenuButton<String>(
                    key: const ValueKey('nav-more'),
                    tooltip: 'Другие разделы',
                    onSelected: context.go,
                    itemBuilder: (context) => [
                      for (final s in more)
                        PopupMenuItem(
                          key: ValueKey('nav-${s.id}'),
                          value: s.location,
                          child: Row(
                            children: [
                              Icon(s.icon, size: 18),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ещё',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 12),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.color,
    required this.child,
    this.topOnly = false,
  });

  final Color color;
  final Widget child;

  final bool topOnly;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: topOnly
            ? const BorderRadius.vertical(top: Radius.circular(radiusPanel))
            : BorderRadius.circular(radiusPanel),
      ),
      child: child,
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: extended
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_outlined, color: scheme.primary, size: 30),
          if (extended) ...[
            const SizedBox(width: 10),
            Text(
              'Салон красоты',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentFrame extends StatelessWidget {
  const _ContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          key: const ValueKey('content-frame'),
          width: constraints.maxWidth.clamp(0, maxContentWidth),
          height: constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.sections, required this.selectedId});

  final List<NavSection> sections;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final selected = sections.indexWhere((s) => s.id == selectedId);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              key: const ValueKey('main-nav'),
              leading: const _Brand(extended: false),
              selectedIndex: selected == -1 ? null : selected,
              onDestinationSelected: (i) => context.go(sections[i].location),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    label: Text(s.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.sections, required this.selectedId});

  final List<NavSection> sections;
  final String? selectedId;

  static const _maxPrimary = 3;

  @override
  Widget build(BuildContext context) {
    final primary = sections.where((s) => s.primary).take(_maxPrimary).toList();
    final rest = [
      for (final s in sections)
        if (!primary.contains(s)) s,
    ];
    final selectedIndex = primary.indexWhere((s) => s.id == selectedId);
    final inRest = rest.any((s) => s.id == selectedId);

    final separator = Theme.of(context).colorScheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: separator, width: 0.5)),
      ),
      child: NavigationBar(
        key: const ValueKey('bottom-nav'),
        selectedIndex: inRest
            ? primary.length
            : (selectedIndex == -1 ? 0 : selectedIndex),
        onDestinationSelected: (i) {
          if (i < primary.length) {
            context.go(primary[i].location);
          } else {
            _showMore(context, rest);
          }
        },
        destinations: [
          for (final s in primary)
            NavigationDestination(icon: Icon(s.icon), label: s.label),
          if (rest.isNotEmpty)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz, key: ValueKey('nav-more')),
              label: 'Ещё',
            ),
        ],
      ),
    );
  }

  void _showMore(BuildContext context, List<NavSection> rest) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        children: [
          for (final s in rest)
            ListTile(
              key: ValueKey('more-${s.id}'),
              leading: Icon(s.icon),
              title: Text(s.label),
              selected: s.id == selectedId,
              onTap: () {
                Navigator.of(sheet).pop();
                context.go(s.location);
              },
            ),
        ],
      ),
    );
  }
}
