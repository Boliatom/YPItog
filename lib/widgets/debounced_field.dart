import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebouncedField extends StatefulWidget {
  const DebouncedField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.delay = const Duration(milliseconds: 400),
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.hint,
    this.width,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String? hint;
  final Duration delay;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final double? width;

  @override
  State<DebouncedField> createState() => _DebouncedFieldState();
}

class _DebouncedFieldState extends State<DebouncedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  Timer? _timer;

  @override
  void didUpdateWidget(DebouncedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedOutside = widget.value != oldWidget.value;
    if (changedOutside && widget.value != _controller.text && _timer == null) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule(String text) {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      _timer = null;
      widget.onChanged(text);
    });
    setState(() {});
  }

  void _commitNow(String text) {
    _timer?.cancel();
    _timer = null;
    widget.onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Очистить',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  _commitNow('');
                  setState(() {});
                },
              ),
      ),
      onChanged: _schedule,
      onSubmitted: _commitNow,
    );
    return widget.width == null
        ? field
        : SizedBox(width: widget.width, child: field);
  }
}
