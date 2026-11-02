import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/date_format.dart';
import '../core/layout.dart';
import '../domain/booking_rules.dart';
import '../domain/booking_service.dart';
import '../models/rec.dart';
import '../schema/entity_schema.dart';
import '../schema/schemas.dart';
import '../state/auth_notifier.dart';
import '../state/reference_cache.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/salon_scaffold.dart';

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.simulateConflict = false});

  final bool simulateConflict;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final ReferenceCache _refs = context.read<ReferenceCache>();
  late final BookingService _booking = context.read<BookingService>();
  final _comment = TextEditingController();

  final Set<String> _serviceIds = {};
  String? _masterId;
  DateTime? _day;
  DateTime? _slot;
  List<DateTime>? _slots;
  int _discount = 0;
  bool _loading = true;
  bool _slotsLoading = false;
  bool _saving = false;
  String? _loadError;
  String? _banner;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final clientId = context.read<AuthNotifier>().user?.clientId;
    try {
      await Future.wait([
        _refs.load('services'),
        _refs.load('masters'),
        _refs.load('service_categories'),
      ]);
      final discount = clientId == null || clientId.isEmpty
          ? 0
          : await _booking.discountFor(clientId);
      if (!mounted) return;
      setState(() {
        _discount = discount;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.message;
        });
      }
    }
  }

  List<Rec> get _services => [
    for (final s in _refs.cached('services'))
      if (s.flag('active')) s,
  ];

  List<Rec> get _chosen => [
    for (final s in _services)
      if (_serviceIds.contains(s.id)) s,
  ];

  int get _minutes =>
      _chosen.fold(0, (a, s) => a + (s.integer('durationMin') ?? 0));
  num get _sum => _chosen.fold<num>(0, (a, s) => a + (s.number('price') ?? 0));

  List<Rec> get _eligibleMasters => [
    for (final m in _refs.cached('masters'))
      if (_serviceIds.isNotEmpty &&
          _serviceIds.every((id) => m.refs('services').contains(id)))
        m,
  ];

  Future<void> _reloadSlots() async {
    final master = _masterId;
    final day = _day;
    if (master == null || day == null || _serviceIds.isEmpty) {
      setState(() {
        _slots = null;
        _slot = null;
      });
      return;
    }
    final serial = ++_serial;
    setState(() {
      _slotsLoading = true;
      _slot = null;
    });
    try {
      final slots = await _booking.freeSlotsFor(
        masterId: master,
        day: day,
        durationMin: _minutes,
      );
      if (!mounted || serial != _serial) return;
      setState(() {
        _slots = slots;
        _slotsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || serial != _serial) return;
      setState(() {
        _slots = null;
        _slotsLoading = false;
        _banner = e.message;
      });
    }
  }

  void _toggleService(String id, bool on) {
    setState(() {
      on ? _serviceIds.add(id) : _serviceIds.remove(id);
      if (_masterId != null &&
          !_eligibleMasters.any((m) => m.id == _masterId)) {
        _masterId = null;
      }
      _banner = null;
    });
    _reloadSlots();
  }

  DateTime _firstWorkingDay(DateTime now) {
    var day = now.add(const Duration(days: 1));
    if (day.weekday == DateTime.sunday) day = day.add(const Duration(days: 1));
    return day;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? _firstWorkingDay(now),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _day = picked;
      _banner = null;
    });
    _reloadSlots();
  }

  Future<void> _submit() async {
    final slot = _slot;
    final clientId = context.read<AuthNotifier>().user?.clientId;
    if (slot == null || _masterId == null || clientId == null) return;
    setState(() {
      _saving = true;
      _banner = null;
    });
    try {
      if (widget.simulateConflict) {
        throw const ConflictException(
          'Это время у мастера уже занято. Выберите другое время.',
        );
      }
      await _booking.book(
        clientId: clientId,
        masterId: _masterId!,
        serviceIds: _serviceIds.toList(),
        startsAt: slot,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы записаны. Мы ждём вас!')),
      );
      context.go('/my-appointments');
    } on ConflictException catch (e) {
      if (!mounted) return;
      setState(() => _banner = e.message);
      await _reloadSlots();
    } on ApiException catch (e) {
      if (mounted) setState(() => _banner = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, Widget child, {String? key}) => Card(
    key: key == null ? null : ValueKey(key),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    context.watch<ReferenceCache>();
    return SalonScaffold(
      title: 'Запись на услугу',
      subtitle: 'Выберите услуги, мастера и свободное время',
      section: 'book',
      body: _loading
          ? const LoadingPanel()
          : _loadError != null
          ? ErrorPanel(message: _loadError!, onRetry: _init)
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = _refs.cached('service_categories');
    final masters = _eligibleMasters;
    final total = discountedPrice(_sum, _discount);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxFormWidth),
        child: ListView(
          children: [
            if (_banner != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _banner!,
                      key: const ValueKey('booking-banner'),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            _section(
              '1. Услуги',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in categories)
                    if (_services.any((s) => s.ref('category') == c.id)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          titleOf(c),
                          style: TextStyle(color: scheme.primary),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final s in _services)
                            if (s.ref('category') == c.id)
                              FilterChip(
                                key: ValueKey('service-${s.id}'),
                                label: Text(
                                  '${s.text('name')} · ${numText(s.number('price') ?? 0)} ₽',
                                ),
                                selected: _serviceIds.contains(s.id),
                                onSelected: (on) => _toggleService(s.id, on),
                              ),
                        ],
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              '2. Мастер',
              _serviceIds.isEmpty
                  ? const Text('Сначала выберите хотя бы одну услугу.')
                  : masters.isEmpty
                  ? const Text(
                      'Ни один мастер не выполняет все выбранные услуги сразу. '
                      'Уберите часть услуг или запишитесь отдельно.',
                      key: ValueKey('no-masters'),
                    )
                  : DropdownButtonFormField<String>(
                      key: const ValueKey('booking-master'),
                      initialValue: masters.any((m) => m.id == _masterId)
                          ? _masterId
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Мастер'),
                      items: [
                        for (final m in masters)
                          DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.text('fullName')} · стаж ${m.integer('experienceYears') ?? 0} лет',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _masterId = v;
                          _banner = null;
                        });
                        _reloadSlots();
                      },
                    ),
            ),
            const SizedBox(height: 12),
            _section(
              '3. Дата и время',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('booking-day'),
                    onPressed: _masterId == null ? null : _pickDay,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _day == null
                          ? 'Выбрать дату'
                          : formatDay(
                              DateTime.utc(_day!.year, _day!.month, _day!.day),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_slotsLoading)
                    const LinearProgressIndicator()
                  else if (_slots != null && _slots!.isEmpty)
                    const Text(
                      'На эту дату нет свободного времени. Выберите другой день.',
                      key: ValueKey('no-slots'),
                    )
                  else if (_slots != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final slot in _slots!)
                          ChoiceChip(
                            key: ValueKey('slot-${_time(slot)}'),
                            label: Text(_time(slot)),
                            selected: _slot == slot,
                            onSelected: (_) => setState(() => _slot = slot),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              '4. Подтверждение',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Длительность: $_minutes мин'),
                  Text('Стоимость без скидки: ${numText(_sum)} ₽'),
                  Text('Скидка по карте: $_discount%'),
                  Text(
                    'Итого: $total ₽',
                    key: const ValueKey('booking-total'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('booking-comment'),
                    controller: _comment,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey('booking-submit'),
                    onPressed: (_slot == null || _saving) ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Записаться'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
