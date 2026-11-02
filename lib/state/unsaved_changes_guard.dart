import 'package:flutter/material.dart';

class UnsavedChangesGuard {
  bool _dirty = false;
  bool _saving = false;
  bool _approved = false;
  Future<bool>? _pending;

  bool get dirty => _dirty;
  bool get saving => _saving;

  bool get canLeave => _approved || (!_dirty && !_saving);

  void reset() {
    _dirty = false;
    _saving = false;
    _approved = false;
    _pending = null;
  }

  void setDirty(bool value) {
    if (_dirty == value) return;
    _dirty = value;
    if (value) _approved = false;
  }

  void setSaving(bool value) => _saving = value;

  Future<bool> confirm(BuildContext context) async {
    if (_saving) return false;
    if (canLeave) return true;
    final pending = _pending;
    if (pending != null) return pending;

    final future = showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
        title: const Text('Есть несохранённые изменения'),
        content: const Text(
          'Если уйти со страницы, изменения в форме будут потеряны.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('stay-on-form'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            key: const ValueKey('discard-changes'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уйти без сохранения'),
          ),
        ],
      ),
    ).then((value) => value ?? false);

    _pending = future;
    final confirmed = await future;
    _pending = null;
    if (confirmed) _approved = true;
    return confirmed;
  }
}
