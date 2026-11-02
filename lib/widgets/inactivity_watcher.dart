import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_notifier.dart';

class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  late final AuthNotifier _auth = context.read<AuthNotifier>();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _auth.recordActivity();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _auth.recordActivity(),
            onPointerSignal: (_) => _auth.recordActivity(),
            onPointerMove: (_) => _auth.recordActivity(passive: true),
            onPointerHover: (_) => _auth.recordActivity(passive: true),
            child: widget.child,
          ),
        ),
        ValueListenableBuilder<int?>(
          valueListenable: _auth.inactivityCountdown,
          builder: (context, seconds, _) => seconds == null
              ? const SizedBox.shrink()
              : _WarningBanner(seconds: seconds, onKeep: _auth.recordActivity),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.seconds, required this.onKeep});

  final int seconds;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Material(
              key: const ValueKey('inactivity-banner'),
              elevation: 6,
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          'Нет активности. Выход из системы через $seconds с.',
                          key: const ValueKey('inactivity-text'),
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('keep-session'),
                      onPressed: onKeep,
                      child: const Text('Остаться в системе'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
