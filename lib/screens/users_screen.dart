import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_user.dart';
import '../auth/role.dart';
import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../repositories/auth_api.dart';
import '../state/auth_notifier.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/salon_scaffold.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  int _page = 1;
  int _size = 10;
  PageResult<AppUser>? _result;
  String? _error;
  String? _operationError;
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<UserRepository>().find(
        page: _page,
        size: _size,
      );
      if (!mounted) return;
      setState(() {
        _result = page;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeRole(AppUser user, Role role) async {
    setState(() {
      _busyId = user.id;
      _operationError = null;
    });
    try {
      await context.read<UserRepository>().changeRole(user.id, role);
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _operationError = e.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = context.watch<AuthNotifier>().user;
    final result = _result;
    return SalonScaffold(
      title: 'Пользователи и роли',
      subtitle: 'Назначайте роли: клиент, мастер или администратор',
      section: 'users',
      body: _loading && result == null
          ? const LoadingPanel()
          : _error != null && result == null
          ? ErrorPanel(message: _error!, onRetry: _load)
          : Column(
              children: [
                if (_operationError != null)
                  OperationBanner(
                    message: _operationError!,
                    onClose: () => setState(() => _operationError = null),
                  ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final user in result!.items)
                        Card(
                          key: ValueKey('user-${user.id}'),
                          child: ListTile(
                            title: Text(user.displayName),
                            subtitle: Text(user.email),
                            trailing: SizedBox(
                              width: 190,
                              child: DropdownButton<Role>(
                                key: ValueKey('role-${user.id}'),
                                isExpanded: true,
                                value: user.role,
                                items: [
                                  for (final r in Role.values)
                                    DropdownMenuItem(
                                      value: r,
                                      child: Text(r.label),
                                    ),
                                ],
                                onChanged:
                                    (_busyId != null || user.id == self?.id)
                                    ? null
                                    : (r) {
                                        if (r != null && r != user.role) {
                                          _changeRole(user, r);
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PaginationBar(
                  page: result,
                  size: _size,
                  onPage: (p) {
                    _page = p;
                    _load();
                  },
                  onSize: (s) {
                    _size = s;
                    _page = 1;
                    _load();
                  },
                ),
              ],
            ),
    );
  }
}
