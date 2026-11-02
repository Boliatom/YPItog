import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout.dart';
import '../state/auth_notifier.dart';

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    if (!auth.enabled) {
      return const Tooltip(
        message: 'Локальные данные: вход не требуется',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.storage_outlined),
        ),
      );
    }

    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final compact = MediaQuery.sizeOf(context).width < compactWidth;
    final textTheme = Theme.of(context).textTheme;
    return PopupMenuButton<String>(
      key: const ValueKey('user-menu'),
      tooltip: 'Учётная запись',
      onSelected: (value) {
        if (value == 'logout') auth.logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            '${user.displayName}\n${user.email} · ${user.role.label}',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: ValueKey('logout'),
          value: 'logout',
          child: Text('Выйти'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 96 : 240),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    key: const ValueKey('user-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!compact)
                    Text(
                      user.role.label,
                      key: const ValueKey('user-role'),
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
