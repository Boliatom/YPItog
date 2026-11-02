import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_monitor.dart';

class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.label = 'Загрузка…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(key: ValueKey('loading-indicator')),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.search_off,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            key: const ValueKey('empty-panel'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: scheme.outline),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              if (onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel ?? 'Сбросить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorPanel extends StatefulWidget {
  const ErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Не удалось загрузить данные',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  State<ErrorPanel> createState() => _ErrorPanelState();
}

class _ErrorPanelState extends State<ErrorPanel> {
  ConnectionMonitor? _monitor;
  int _seenReconnects = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monitor = context.read<ConnectionMonitor?>();
    if (!identical(monitor, _monitor)) {
      _monitor?.removeListener(_onConnection);
      _monitor = monitor?..addListener(_onConnection);
      _seenReconnects = monitor?.reconnects ?? 0;
    }
  }

  @override
  void dispose() {
    _monitor?.removeListener(_onConnection);
    super.dispose();
  }

  void _onConnection() {
    final monitor = _monitor;
    if (monitor == null || !monitor.isOnline) return;
    if (monitor.reconnects != _seenReconnects) {
      _seenReconnects = monitor.reconnects;
      widget.onRetry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            key: const ValueKey('error-panel'),
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('retry-button'),
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OperationBanner extends StatelessWidget {
  const OperationBanner({
    super.key,
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('operation-banner'),
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: 'Скрыть',
              onPressed: onClose,
              icon: Icon(Icons.close, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}
