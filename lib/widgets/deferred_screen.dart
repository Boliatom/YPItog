import 'package:flutter/material.dart';

import 'feedback_panel.dart';

class DeferredScreen extends StatefulWidget {
  const DeferredScreen({super.key, required this.load, required this.builder});

  final Future<void> Function() load;

  final Widget Function() builder;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _loading = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder();
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Загрузка раздела…')),
          body: snapshot.hasError
              ? ErrorPanel(
                  title: 'Не удалось загрузить раздел',
                  message: 'Проверьте подключение к интернету и повторите.',
                  onRetry: () => setState(() => _loading = widget.load()),
                )
              : const LoadingPanel(label: 'Загружаем раздел…'),
        );
      },
    );
  }
}
