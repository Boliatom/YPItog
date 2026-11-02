import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';
import '../validation/password_rules.dart';
import '../validation/validators.dart' as v;
import '../widgets/auth_frame.dart';
import '../widgets/password_checklist.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  FormFieldValidator<String> _check(
    String field,
    FormFieldValidator<String> own,
  ) => (value) {
    return own(value) ?? _serverErrors[field];
  };

  void _forget(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    _serverErrors = {};
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthNotifier>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.register(
        email: _email.text,
        password: _password.text,
        fullName: _fullName.text,
      );
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.errors;
        _error = e.errors.isEmpty ? e.message : null;
      });
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      title: 'Регистрация',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('reg-fullname'),
              controller: _fullName,
              autofocus: true,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Имя и фамилия',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: _check('name', (value) {
                return v.required(value, 'Введите имя') ??
                    v.minLength(2)(value) ??
                    v.maxLength(100)(value);
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('reg-email'),
              controller: _email,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Эл. почта',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _forget('email'),
              validator: _check('email', (value) {
                return v.required(value, 'Введите почту') ?? v.email(value);
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('reg-password'),
              controller: _password,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const ValueKey('reg-toggle-password'),
                  tooltip: _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _forget('password'),
              validator: _check('password', validatePassword),
            ),
            const SizedBox(height: 8),
            PasswordChecklist(password: _password.text),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('reg-confirm'),
              controller: _confirm,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: !_showPassword,
              decoration: const InputDecoration(
                labelText: 'Повторите пароль',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Повторите пароль';
                return value == _password.text ? null : 'Пароли не совпадают';
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AuthMessage(
                key: const ValueKey('reg-error'),
                text: _error!,
                isError: true,
                icon: Icons.error_outline,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('reg-submit'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Зарегистрироваться'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('to-login'),
              onPressed: _busy ? null : () => context.go('/login'),
              child: const Text('Уже есть учётная запись? Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
