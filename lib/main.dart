import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'app_environment.dart';
import 'core/config.dart';
import 'widgets/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final AppEnvironment environment;
  try {
    environment = await AppEnvironment.create();
  } on MissingApiUrlException {
    runApp(const ConfigErrorApp());
    return;
  }

  runApp(
    SalonProviders(
      environment: environment,
      child: SalonApp(startupNotice: environment.notice),
    ),
  );
}
