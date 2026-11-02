import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'widgets/inactivity_watcher.dart';

class SalonApp extends StatefulWidget {
  const SalonApp({super.key, this.initialLocation, this.startupNotice});

  final String? initialLocation;

  final String? startupNotice;

  @override
  State<SalonApp> createState() => _SalonAppState();
}

class _SalonAppState extends State<SalonApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  late final GoRouter _router = createAppRouter(
    auth: context.read<AuthNotifier>(),
    initialLocation: widget.initialLocation,
  );

  @override
  void initState() {
    super.initState();
    final notice = widget.startupNotice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(notice), duration: const Duration(seconds: 8)),
        );
      });
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Салон красоты',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const IosScrollBehavior(),
      routerConfig: _router,
      builder: (context, child) =>
          InactivityWatcher(child: child ?? const SizedBox.shrink()),
    );
  }
}
