import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key, this.deniedPath});

  final String? deniedPath;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.role;
    final where = (deniedPath == null || deniedPath!.isEmpty)
        ? 'Этот раздел'
        : 'Раздел $deniedPath';
    final who = role == null ? '' : ' роли «${role.label}»';
    return SalonScaffold(
      title: 'Нет доступа',
      body: EmptyPanel(
        icon: Icons.lock_outline,
        title: '403 — доступ запрещён',
        message: '$where недоступен$who. Нужны другие права.',
        actionLabel: auth.enabled ? 'На главную' : 'К списку книг',
        onAction: () => context.go(auth.enabled ? '/' : '/books'),
      ),
    );
  }
}
