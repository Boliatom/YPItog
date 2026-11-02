typedef FieldValidator = String? Function(String? value);

String? _trimmed(String? value) => value?.trim();

String? required(String? value, [String message = 'Обязательное поле']) {
  final text = _trimmed(value);
  return (text == null || text.isEmpty) ? message : null;
}

FieldValidator maxLength(int limit) => (value) {
  final length = _trimmed(value)?.length ?? 0;
  return length > limit ? 'Не длиннее $limit символов' : null;
};

FieldValidator minLength(int limit) => (value) {
  final text = _trimmed(value) ?? '';
  return (text.isNotEmpty && text.length < limit)
      ? 'Не короче $limit символов'
      : null;
};

FieldValidator intInRange(
  int min,
  int max, {
  bool optional = false,
  String? emptyMessage,
}) => (value) {
  final text = _trimmed(value) ?? '';
  if (text.isEmpty) return optional ? null : (emptyMessage ?? 'Введите число');
  final number = int.tryParse(text);
  if (number == null) return 'Нужно целое число';
  if (number < min || number > max) return 'От $min до $max';
  return null;
};

FieldValidator positiveInt({int max = 100000, bool optional = false}) =>
    (value) {
      final text = _trimmed(value) ?? '';
      if (text.isEmpty) return optional ? null : 'Введите количество';
      final number = int.tryParse(text);
      if (number == null) return 'Нужно целое число';
      if (number <= 0) return 'Должно быть больше нуля';
      if (number > max) return 'Не больше $max';
      return null;
    };

final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

String? email(String? value) {
  final text = _trimmed(value) ?? '';
  if (text.isEmpty) return null;
  return _emailPattern.hasMatch(text) ? null : 'Некорректный адрес почты';
}

String? phone(String? value) {
  final text = _trimmed(value) ?? '';
  if (text.isEmpty) return null;
  final digits = text.replaceAll(RegExp(r'\D'), '');
  final charsOk = RegExp(r'^\+?[\d\s\-()]+$').hasMatch(text);
  return (charsOk && digits.length >= 7 && digits.length <= 15)
      ? null
      : 'Некорректный номер телефона';
}

String? isbn(String? value) {
  final compact = canonicalIsbn(value ?? '');
  if (compact.isEmpty) return null;
  final ok =
      RegExp(r'^\d{13}$').hasMatch(compact) ||
      RegExp(r'^\d{9}[\dX]$').hasMatch(compact);
  return ok ? null : 'ISBN: 10 или 13 цифр, дефисы допустимы';
}

String canonicalIsbn(String value) =>
    value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

FieldValidator pattern(RegExp regExp, String message) => (value) {
  final text = _trimmed(value) ?? '';
  if (text.isEmpty) return null;
  return regExp.hasMatch(text) ? null : message;
};

FieldValidator compose(List<FieldValidator> validators) => (value) {
  for (final validator in validators) {
    final message = validator(value);
    if (message != null) return message;
  }
  return null;
};

int get currentYear => DateTime.now().year;
