import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return SalonScaffold(
      title: 'Страница не найдена',
      body: EmptyPanel(
        icon: Icons.travel_explore,
        title: '404 — такой страницы нет',
        message: 'Адрес $location не существует.',
        actionLabel: 'К списку книг',
        onAction: () => context.go('/books'),
      ),
    );
  }
}
