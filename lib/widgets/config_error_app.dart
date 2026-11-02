import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Салон красоты',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.settings_suggest_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Не задан адрес сервера',
                      key: const ValueKey('config-error-title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Адрес API задаётся при сборке, а не в исходном коде. '
                      'Соберите или запустите приложение с параметром '
                      'API_BASE_URL:',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const SelectionArea(
                        child: Text(
                          'flutter build web --release \\\n'
                          '  --dart-define=API_BASE_URL=<адрес API>',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Для работы без сервера (данные в браузере) добавьте '
                      '--dart-define=BACKEND=persistent.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
