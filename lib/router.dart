import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/route_access.dart';
import 'schema/entity_schema.dart';
import 'schema/schemas.dart';
import 'screens/booking_screen.dart' deferred as booking;
import 'screens/dashboard_screen.dart';
import 'screens/entity_detail_screen.dart';
import 'screens/entity_form_screen.dart' deferred as form_screen;
import 'screens/entity_list_screen.dart';
import 'screens/forbidden_screen.dart';
import 'screens/login_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/register_screen.dart' deferred as register;
import 'screens/stats_screen.dart' deferred as stats;
import 'screens/users_screen.dart' deferred as users;
import 'state/auth_notifier.dart';
import 'state/unsaved_changes_guard.dart';
import 'widgets/deferred_screen.dart';

Future<void> loadDeferredLibraries() => Future.wait([
  booking.loadLibrary(),
  form_screen.loadLibrary(),
  register.loadLibrary(),
  stats.loadLibrary(),
  users.loadLibrary(),
]);

GoRouter createAppRouter({
  required AuthNotifier auth,
  String? initialLocation,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    redirect: (context, state) => _guard(auth, state),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(returnTo: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => DeferredScreen(
          load: register.loadLibrary,
          builder: () => register.RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) =>
            ForbiddenScreen(deniedPath: state.uri.queryParameters['path']),
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) => DeferredScreen(
          load: booking.loadLibrary,
          builder: () => booking.BookingScreen(
            simulateConflict: state.uri.queryParameters['__fail'] == '409',
          ),
        ),
      ),
      GoRoute(
        path: '/my-appointments',
        builder: (context, state) => EntityListScreen(
          key: const ValueKey('list-my-appointments'),
          schema: appointmentsSchema,
          uri: state.uri,
          mode: ListMode.ownClient,
        ),
      ),
      GoRoute(
        path: '/my-schedule',
        builder: (context, state) => EntityListScreen(
          key: const ValueKey('list-my-schedule'),
          schema: appointmentsSchema,
          uri: state.uri,
          mode: ListMode.ownMaster,
        ),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => DeferredScreen(
          load: users.loadLibrary,
          builder: () => users.UsersScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/stats',
        builder: (context, state) => DeferredScreen(
          load: stats.loadLibrary,
          builder: () => stats.StatsScreen(),
        ),
      ),
      for (final schema in allSchemas) ..._entityRoutes(schema),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
  );
}

String? _guard(AuthNotifier auth, GoRouterState state) {
  final uri = state.uri;
  final needed = requiredPermission(uri);

  if (guestPaths.contains(uri.path)) {
    if (!auth.isAuthenticated) return null;
    final back = safeReturnPath(uri.queryParameters['from']);
    if (back != null) {
      final backNeeds = requiredPermission(Uri.parse(back));
      if (backNeeds == null || auth.can(backNeeds)) return back;
    }
    return '/';
  }

  if (!auth.isAuthenticated) {
    return loginLocation(
      returnTo: auth.rememberReturnAddress ? uri.toString() : null,
    );
  }

  if (needed != null && !auth.can(needed)) return forbiddenLocation(uri);
  return null;
}

Future<bool> _confirmLeave(BuildContext context, GoRouterState state) {
  final auth = context.read<AuthNotifier>();
  final needed = requiredPermission(state.uri);
  final closed = !auth.isAuthenticated || (needed != null && !auth.can(needed));
  if (closed) return Future.value(true);
  return context.read<UnsavedChangesGuard>().confirm(context);
}

List<GoRoute> _entityRoutes(EntitySchema schema) {
  String? idOf(GoRouterState state) {
    final id = state.pathParameters['id'];
    return (id == null || !RegExp(r'^[A-Za-z0-9_-]{1,40}$').hasMatch(id))
        ? null
        : id;
  }

  return [
    GoRoute(
      path: schema.path,
      builder: (context, state) => EntityListScreen(
        key: ValueKey('list-${schema.section}'),
        schema: schema,
        uri: state.uri,
      ),
    ),
    GoRoute(
      path: '${schema.path}/new',
      onExit: _confirmLeave,
      builder: (context, state) => DeferredScreen(
        key: ValueKey('new-${schema.section}'),
        load: form_screen.loadLibrary,
        builder: () => form_screen.EntityFormScreen(schema: schema),
      ),
    ),
    GoRoute(
      path: '${schema.path}/:id/edit',
      onExit: _confirmLeave,
      builder: (context, state) {
        final id = idOf(state);
        return id == null
            ? NotFoundScreen(location: state.uri.path)
            : DeferredScreen(
                key: ValueKey('edit-${schema.section}-$id'),
                load: form_screen.loadLibrary,
                builder: () =>
                    form_screen.EntityFormScreen(schema: schema, id: id),
              );
      },
    ),
    GoRoute(
      path: '${schema.path}/:id',
      builder: (context, state) {
        final id = idOf(state);
        return id == null
            ? NotFoundScreen(location: state.uri.path)
            : EntityDetailScreen(
                key: ValueKey('detail-${schema.section}-$id'),
                schema: schema,
                id: id,
              );
      },
    ),
  ];
}
