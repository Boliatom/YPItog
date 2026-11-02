import 'package:flutter/material.dart';

import '../validation/password_rules.dart';

class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = passwordScore(password);
    final total = passwordRules.length;
    final (label, color) = password.isEmpty
        ? ('Пароль не введён', scheme.outline)
        : switch (score) {
            0 || 1 => ('Слабый пароль', scheme.error),
            2 => ('Средний пароль', Colors.orange.shade800),
            _ => ('Надёжный пароль', Colors.green.shade700),
          };

    return Column(
      key: const ValueKey('password-checklist'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            key: const ValueKey('password-strength-bar'),
            value: score / total,
            minHeight: 6,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          password.isEmpty ? label : '$label ($score из $total)',
          key: const ValueKey('password-strength'),
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        for (final rule in passwordRules)
          Semantics(
            container: true,
            excludeSemantics: true,
            label:
                '${rule.label}: ${rule.test(password) ? 'выполнено' : 'не выполнено'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                key: ValueKey('rule-${rule.id}'),
                children: [
                  Icon(
                    rule.test(password)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: rule.test(password)
                        ? Colors.green.shade700
                        : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: TextStyle(
                        color: rule.test(password)
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
