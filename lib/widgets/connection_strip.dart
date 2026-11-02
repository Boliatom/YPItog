import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_monitor.dart';

class ConnectionStrip extends StatelessWidget {
  const ConnectionStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<ConnectionMonitor>();
    final scheme = Theme.of(context).colorScheme;

    Widget? strip;
    if (!monitor.isOnline) {
      strip = Material(
        key: const ValueKey('connection-offline'),
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Нет связи с сервером. Приложение проверяет её само и '
                    'обновит данные, как только связь вернётся.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('connection-retry'),
                onPressed: monitor.isChecking ? null : monitor.checkNow,
                child: Text(monitor.isChecking ? 'Проверяем…' : 'Проверить'),
              ),
            ],
          ),
        ),
      );
    } else if (monitor.recentlyRestored) {
      strip = Material(
        key: const ValueKey('connection-restored'),
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.cloud_done_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Связь восстановлена.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topCenter,
      child: strip ?? const SizedBox(width: double.infinity),
    );
  }
}
