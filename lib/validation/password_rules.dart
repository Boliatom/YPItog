class PasswordRule {
  const PasswordRule(this.id, this.label, this.test);

  final String id;
  final String label;
  final bool Function(String password) test;
}

const minPasswordLength = 8;

final _digit = RegExp(r'\d');

final _special = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

final passwordRules = <PasswordRule>[
  PasswordRule(
    'length',
    'Не короче $minPasswordLength символов',
    (p) => p.length >= minPasswordLength,
  ),
  PasswordRule('digit', 'Есть хотя бы одна цифра', _digit.hasMatch),
  PasswordRule('special', 'Есть спецсимвол', _special.hasMatch),
];

int passwordScore(String password) =>
    passwordRules.where((r) => r.test(password)).length;

bool isStrongPassword(String password) =>
    passwordScore(password) == passwordRules.length;

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Введите пароль';
  for (final rule in passwordRules) {
    if (!rule.test(password)) return rule.label;
  }
  return null;
}
