import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/route_access.dart';
import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';
import '../widgets/auth_frame.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = context.read<AuthNotifier>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.login(_username.text, _password.text);
    } on ValidationException {
      if (mounted) setState(() => _error = 'Неверная почта или пароль.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final notice = auth.notice;
    final registerTarget = loginLocation(
      returnTo: widget.returnTo,
    ).replaceFirst('/login', '/register');

    return AuthFrame(
      title: 'Вход в систему',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notice != null) ...[
              AuthMessage(
                key: const ValueKey('session-notice'),
                text: notice,
                icon: Icons.lock_clock_outlined,
                onClose: auth.clearNotice,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const ValueKey('login-username'),
              controller: _username,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Эл. почта',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите почту' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('login-password'),
              controller: _password,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const ValueKey('login-toggle-password'),
                  tooltip: _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Введите пароль' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthMessage(
                key: const ValueKey('login-error'),
                text: _error!,
                isError: true,
                icon: Icons.error_outline,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('login-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Войти'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('to-register'),
              onPressed: _busy ? null : () => context.go(registerTarget),
              child: const Text('Нет учётной записи? Зарегистрироваться'),
            ),
            const Divider(),
            Text(
              'Для проверки: admin@salon.ru / Admin2026!, '
              'master@salon.ru / Master2026!, client@salon.ru / Client2026!.',
              key: const ValueKey('login-hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
