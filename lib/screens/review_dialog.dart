import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../models/rec.dart';
import '../repositories/record_repository.dart';

Future<bool> showReviewDialog(
  BuildContext context, {
  required Rec appointment,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ReviewDialog(appointment: appointment),
  );
  return saved ?? false;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.appointment});

  final Rec appointment;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _text = TextEditingController();
  int _rating = 5;
  bool _busy = false;
  String? _error;
  String? _textError;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_text.text.trim().length > 500) {
      setState(() => _textError = 'Не длиннее 500 символов');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _textError = null;
    });
    final repos = context.read<SalonRepositories>();
    try {
      await repos.reviews.create({
        'appointment': widget.appointment.id,
        'client': widget.appointment.ref('client'),
        'master': widget.appointment.ref('master'),
        'rating': _rating,
        'text': _text.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ValidationException catch (e) {
      if (!mounted) return;
      final already =
          e.errors['appointment'] != null &&
          e.errors['appointment']!.contains('используется');
      setState(() {
        _busy = false;
        _textError = e.errors['text'];
        _error = already
            ? 'Отзыв об этой записи уже оставлен.'
            : (e.errors['appointment'] ?? e.errors['rating'] ?? e.message);
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отзыв о визите'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Оценка'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 1; i <= 5; i++)
                    ChoiceChip(
                      key: ValueKey('rating-$i'),
                      label: Text('$i'),
                      selected: _rating == i,
                      onSelected: (_) => setState(() => _rating = i),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('review-text'),
                controller: _text,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Комментарий (необязательно)',
                  errorText: _textError,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('review-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const ValueKey('review-submit'),
          onPressed: _busy ? null : _submit,
          child: const Text('Отправить'),
        ),
      ],
    );
  }
}
