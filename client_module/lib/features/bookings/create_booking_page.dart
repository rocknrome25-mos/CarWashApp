import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import '../../core/realtime/realtime_client.dart';
import 'payment_page.dart';

enum _BayMode { any, bay1, bay2 }

class CreateBookingPage extends StatefulWidget {
  final AppRepository repo;
  final String? preselectedServiceId;

  const CreateBookingPage({
    super.key,
    required this.repo,
    this.preselectedServiceId,
  });

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  static const int _slotStepMin = 30;
  static const int _minLeadMin = 10;

  static const int _openHour = 8;
  static const int _closeHour = 22;

  static const int _quickDaysTotal = 14;
  static const int _quickPinnedDays = 2;

  // ✅ правила
  static const int _bufferMin = 15;
  static const int _depositRub = 500;

  // 🎨 бренд (как ты хочешь)
  static const Color _pink = Color(0xFFE7A2B3); // розовый как выбор даты/слотов
  static const Color _greenLine = Color(0xFF2DBD6E); // зелёная линия
  static const Color _blueLine = Color(0xFF2D9CDB); // синяя линия

  final _formKey = GlobalKey<FormState>();
  final Map<DateTime, GlobalKey> _dateKeys = {};

  List<Car> _cars = const [];
  List<Service> _services = const [];

  // ✅ busy по каждому посту, чтобы any-mode был корректным для длительности
  Map<int, List<DateTimeRange>> _busyByBay = const {1: [], 2: []};

  String? carId;
  String? serviceId;

  _BayMode _bayMode = _BayMode.any;

  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime? _selectedSlotStart;

  // ✅ если режим "Любая линия" — при выборе слота запоминаем какая линия реально будет
  int? _pickedBayIdForAny;

  final _commentCtrl = TextEditingController();

  bool _loading = true;
  Object? _error;
  bool _saving = false;

  bool _didInitialAutoPick = false;

  StreamSubscription<BookingRealtimeEvent>? _rtSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _rtSub?.cancel();
    _rtSub = widget.repo.bookingEvents.listen((ev) async {
      if (!mounted) return;

      final affected = ev.type == 'booking.changed';
      if (!affected) return;

      // ✅ всегда обновляем оба поста
      await _refreshBusy(force: true);

      // если выбранный слот стал недоступен — сбрасываем выбор
      final cur = _selectedSlotStart;
      if (cur != null && _isBusySlot(cur)) {
        if (!mounted) return;
        setState(() {
          _selectedSlotStart = null;
          _pickedBayIdForAny = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _commentCtrl.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  GlobalKey _keyForDate(DateTime d) {
    final dd = _dateOnly(d);
    return _dateKeys.putIfAbsent(dd, () => GlobalKey());
  }

  void _scrollDateIntoCenter(DateTime d) {
    final dd = _dateOnly(d);

    final today = _dateOnly(DateTime.now());
    final diff = dd.difference(today).inDays;
    if (diff < _quickPinnedDays) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dateKeys[dd];
      final ctx = key?.currentContext;
      if (ctx == null) return;

      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Service? _findService(String? id) {
    if (id == null) return null;
    for (final s in _services) {
      if (s.id == id) return s;
    }
    return null;
  }

  int _serviceDurationOrDefault(String? sid) {
    final s = _findService(sid);
    final d = s?.durationMin;
    return (d != null && d > 0) ? d : 30;
  }

  int _roundUpToStepMin(int totalMin, int stepMin) {
    if (totalMin <= 0) return 0;
    final q = (totalMin + stepMin - 1) ~/ stepMin;
    return q * stepMin;
  }

  int _effectiveBlockMinForSelectedService() {
    final base = _serviceDurationOrDefault(serviceId);
    final raw = base + _bufferMin;
    return _roundUpToStepMin(raw, _slotStepMin);
  }

  String _fmtDateShort(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}';
  }

  String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  String _carTitleForUi(Car c) {
    final make = c.make.trim();
    final model = c.model.trim();
    if (model.isEmpty || model == '—') {
      return '$make (${c.plateDisplay})';
    }
    return '$make $model (${c.plateDisplay})';
  }

  DateTime _ceilToStep(DateTime dt, int stepMin) {
    final totalMin = dt.hour * 60 + dt.minute;
    final rem = totalMin % stepMin;
    final add = rem == 0 ? 0 : (stepMin - rem);
    final rounded = dt.add(Duration(minutes: add));
    return DateTime(
      rounded.year,
      rounded.month,
      rounded.day,
      rounded.hour,
      rounded.minute,
    );
  }

  DateTime _minSelectableNowLocal() {
    final now = DateTime.now();
    final lead = now.add(const Duration(minutes: _minLeadMin));
    return _ceilToStep(lead, _slotStepMin);
  }

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  int? _currentBayIdOrNull() {
    switch (_bayMode) {
      case _BayMode.any:
        return null;
      case _BayMode.bay1:
        return 1;
      case _BayMode.bay2:
        return 2;
    }
  }

  bool _isBusySlotForBay(DateTime slotStart, int bayId) {
    final blockMin = _effectiveBlockMinForSelectedService();
    final slotEnd = slotStart.add(Duration(minutes: blockMin));

    final ranges = _busyByBay[bayId] ?? const [];
    for (final r in ranges) {
      if (_overlaps(slotStart, slotEnd, r.start, r.end)) return true;
    }
    return false;
  }

  bool _isBusySlot(DateTime slotStart) {
    final bayId = _currentBayIdOrNull();

    if (bayId != null) {
      return _isBusySlotForBay(slotStart, bayId);
    }

    // ✅ any-mode: busy только если оба поста busy на весь блок
    final busy1 = _isBusySlotForBay(slotStart, 1);
    final busy2 = _isBusySlotForBay(slotStart, 2);
    return busy1 && busy2;
  }

  bool _endsBeforeClose(DateTime slotStart) {
    final blockMin = _effectiveBlockMinForSelectedService();
    final end = slotStart.add(Duration(minutes: blockMin));
    final close = DateTime(
      slotStart.year,
      slotStart.month,
      slotStart.day,
      _closeHour,
      0,
    );
    return !end.isAfter(close);
  }

  List<DateTime> _buildSlotsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day, _openHour, 0);
    final end = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final slots = <DateTime>[];
    var cur = start;

    while (cur.isBefore(end)) {
      if (_endsBeforeClose(cur)) slots.add(cur);
      cur = cur.add(const Duration(minutes: _slotStepMin));
    }
    return slots;
  }

  DateTime? _firstFreeSlotForDay(DateTime day) {
    final slots = _buildSlotsForDay(day);
    final minNow = _minSelectableNowLocal();
    final isToday = _dateOnly(day) == _dateOnly(DateTime.now());

    for (final s in slots) {
      if (isToday && s.isBefore(minNow)) continue;
      if (_isBusySlot(s)) continue;
      return s;
    }
    return null;
  }

  Future<int?> _pickBayForSlotAny(DateTime slotStart) async {
    final busy1 = _isBusySlotForBay(slotStart, 1);
    final busy2 = _isBusySlotForBay(slotStart, 2);

    if (!busy1) return 1;
    if (!busy2) return 2;
    return null;
  }

  Future<void> _refreshBusy({bool force = false}) async {
    final day = _selectedDate;
    final from = DateTime(day.year, day.month, day.day, _openHour, 0);
    final to = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final List<List<DateTimeRange>> results =
        await Future.wait<List<DateTimeRange>>([
          widget.repo.getBusySlots(
            bayId: 1,
            from: from,
            to: to,
            forceRefresh: force,
          ),
          widget.repo.getBusySlots(
            bayId: 2,
            from: from,
            to: to,
            forceRefresh: force,
          ),
        ]);

    if (!mounted) return;
    setState(() {
      _busyByBay = {1: results[0], 2: results[1]};
    });

    if (_bayMode == _BayMode.any && _selectedSlotStart != null && mounted) {
      final bay = await _pickBayForSlotAny(_selectedSlotStart!);
      if (!mounted) return;
      setState(() => _pickedBayIdForAny = bay);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.repo.getCars(forceRefresh: true),
        widget.repo.getServices(forceRefresh: true),
      ]);

      final cars = results[0] as List<Car>;
      final services = results[1] as List<Service>;

      final String? selectedCarId = cars.isNotEmpty ? cars.first.id : null;

      String? selectedServiceId =
          widget.preselectedServiceId ??
          (services.isNotEmpty ? services.first.id : null);

      if (widget.preselectedServiceId != null &&
          !services.any((s) => s.id == widget.preselectedServiceId)) {
        selectedServiceId = services.isNotEmpty ? services.first.id : null;
      }

      if (!mounted) return;

      setState(() {
        _cars = cars;
        _services = services;

        carId = selectedCarId;
        serviceId = selectedServiceId;

        _selectedDate = _dateOnly(DateTime.now());
        _selectedSlotStart = null;
        _pickedBayIdForAny = null;

        _loading = false;
      });

      await _refreshBusy(force: true);

      if (!_didInitialAutoPick) {
        final picked = _firstFreeSlotForDay(_selectedDate);
        if (picked != null && mounted) {
          setState(() {
            _selectedSlotStart = picked;
            _didInitialAutoPick = true;
          });

          if (_bayMode == _BayMode.any) {
            final bay = await _pickBayForSlotAny(picked);
            if (mounted) setState(() => _pickedBayIdForAny = bay);
          }
        }
      }

      _scrollDateIntoCenter(_selectedDate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _selectDate(DateTime d) async {
    setState(() {
      _selectedDate = _dateOnly(d);
      _selectedSlotStart = null;
      _pickedBayIdForAny = null;
    });

    _scrollDateIntoCenter(d);
    await _refreshBusy(force: true);
  }

  List<DateTime> _quickDatesAll() {
    final today = _dateOnly(DateTime.now());
    return List.generate(_quickDaysTotal, (i) => today.add(Duration(days: i)));
  }

  List<DateTime> _quickDatesScrollable() {
    final all = _quickDatesAll();
    if (all.length <= _quickPinnedDays) return const [];
    return all.sublist(_quickPinnedDays);
  }

  String _chipLabelForDate(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final diff = _dateOnly(d).difference(today).inDays;
    if (diff == 0) return 'Сегодня';
    return _fmtDateShort(d);
  }

  Color _bayColorForMode(_BayMode m) {
    switch (m) {
      case _BayMode.any:
        return _pink;
      case _BayMode.bay1:
        return _greenLine;
      case _BayMode.bay2:
        return _blueLine;
    }
  }

  String _bayTitleForMode(_BayMode m) {
    switch (m) {
      case _BayMode.any:
        return 'Любая линия';
      case _BayMode.bay1:
        return 'Зелёная линия';
      case _BayMode.bay2:
        return 'Синяя линия';
    }
  }

  String _pickedBayLabel(int bayId) {
    if (bayId == 1) return 'Зелёная линия';
    if (bayId == 2) return 'Синяя линия';
    return 'Линия';
  }

  Color _pickedBayColor(int bayId) {
    if (bayId == 1) return _greenLine;
    if (bayId == 2) return _blueLine;
    return Colors.grey;
  }

  Future<void> _selectBay(_BayMode mode) async {
    setState(() {
      _bayMode = mode;
      _selectedSlotStart = null;
      _pickedBayIdForAny = null;
    });
    await _refreshBusy(force: true);
  }

  Widget _lineSelector() {
    Widget item({
      required _BayMode mode,
      required String title,
      required Color stripe,
    }) {
      final selected = _bayMode == mode;

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async => _selectBay(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? stripe.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? stripe.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 28,
                decoration: BoxDecoration(
                  color: stripe,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: stripe, size: 18)
              else
                Icon(
                  Icons.circle_outlined,
                  color: Colors.black.withValues(alpha: 0.25),
                  size: 18,
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        item(mode: _BayMode.any, title: 'Любая линия', stripe: _pink),
        const SizedBox(height: 8),
        item(mode: _BayMode.bay1, title: 'Зелёная линия', stripe: _greenLine),
        const SizedBox(height: 8),
        item(mode: _BayMode.bay2, title: 'Синяя линия', stripe: _blueLine),
      ],
    );
  }

  List<DateTime> _visibleSlotsForCurrentMode() {
    final allSlots = _buildSlotsForDay(_selectedDate);

    final minNow = _minSelectableNowLocal();
    final isSelectedDayToday = _selectedDate == _dateOnly(DateTime.now());

    final visible = <DateTime>[];
    for (final s in allSlots) {
      if (isSelectedDayToday && s.isBefore(minNow)) continue;
      if (_isBusySlot(s)) continue;
      visible.add(s);
    }
    return visible;
  }

  List<DateTime> _filterByHourRange(
    List<DateTime> slots,
    int fromHour,
    int toHourExclusive,
  ) {
    return slots
        .where((d) => d.hour >= fromHour && d.hour < toHourExclusive)
        .toList();
  }

  ButtonStyle _slotStyleOutlined() {
    return OutlinedButton.styleFrom(
      side: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
      backgroundColor: Colors.black.withValues(alpha: 0.03),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: const StadiumBorder(),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  ButtonStyle _slotStyleFilled() {
    return FilledButton.styleFrom(
      backgroundColor: _pink,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: const StadiumBorder(),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  Widget _slotButton(DateTime s) {
    final selected = _selectedSlotStart == s;
    final label = _fmtTime(s);

    Future<void> select() async {
      setState(() {
        _selectedSlotStart = s;
        _pickedBayIdForAny = null;
      });

      if (_bayMode == _BayMode.any) {
        final bay = await _pickBayForSlotAny(s);
        if (!mounted) return;
        setState(() => _pickedBayIdForAny = bay);
      }
    }

    return selected
        ? FilledButton(
            style: _slotStyleFilled(),
            onPressed: select,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          )
        : OutlinedButton(
            style: _slotStyleOutlined(),
            onPressed: select,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          );
  }

  Widget _timeSection({
    required String title,
    required List<DateTime> slots,
    bool initiallyExpanded = true,
  }) {
    if (slots.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(
            title.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: slots.map(_slotButton).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (carId == null || serviceId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final slot = _selectedSlotStart;
    if (slot == null) return;

    final isToday = _selectedDate == _dateOnly(DateTime.now());
    final minNow = _minSelectableNowLocal();
    if (isToday && slot.isBefore(minNow)) return;

    if (_isBusySlot(slot)) return;

    int? bayIdToSend = _currentBayIdOrNull();
    if (bayIdToSend == null) {
      bayIdToSend = _pickedBayIdForAny;
      bayIdToSend ??= await _pickBayForSlotAny(slot);
      if (bayIdToSend == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Нет доступной линии на это время. Выбери другое.'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final Booking booking = await widget.repo.createBooking(
        carId: carId!,
        serviceId: serviceId!,
        dateTime: slot,
        bayId: bayIdToSend,
        depositRub: _depositRub,
        comment: _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
        bufferMin: _bufferMin,
      );

      if (!mounted) return;

      final service = _findService(serviceId);

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            repo: widget.repo,
            booking: booking,
            service: service,
            depositRub: _depositRub,
          ),
        ),
      );

      if (!mounted) return;

      if (paid == true) {
        Navigator.of(context).pop(true);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Запись создана, но не оплачена.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canProceed() {
    if (_saving) return false;
    if (_cars.isEmpty || _services.isEmpty) return false;
    if (carId == null || serviceId == null) return false;

    final slot = _selectedSlotStart;
    if (slot == null) return false;

    final isToday = _selectedDate == _dateOnly(DateTime.now());
    final minNow = _minSelectableNowLocal();
    if (isToday && slot.isBefore(minNow)) return false;

    if (_isBusySlot(slot)) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Создать запись')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Создать запись')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _bootstrap,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final carIds = _cars.map((c) => c.id).toSet();
    final serviceIds = _services.map((s) => s.id).toSet();
    final safeCarId = (carId != null && carIds.contains(carId)) ? carId : null;
    final safeServiceId = (serviceId != null && serviceIds.contains(serviceId))
        ? serviceId
        : null;

    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final scrollDates = _quickDatesScrollable();

    const chipLabelPadding = EdgeInsets.symmetric(horizontal: 10);
    const chipVD = VisualDensity(horizontal: -2, vertical: -2);

    final service = _findService(safeServiceId);
    final priceRub = service?.priceRub ?? 0;
    final remaining = (priceRub - _depositRub) > 0
        ? (priceRub - _depositRub)
        : 0;

    final visibleSlots = _visibleSlotsForCurrentMode();
    final morningSlots = _filterByHourRange(visibleSlots, _openHour, 12);
    final daySlots = _filterByHourRange(visibleSlots, 12, 17);
    final eveningSlots = _filterByHourRange(visibleSlots, 17, _closeHour);

    final canProceed = _canProceed();

    // ✅ если any-mode и слот выбран, то покажем реальную линию (зел/син)
    final pickedLineText =
        (_bayMode == _BayMode.any && _pickedBayIdForAny != null)
        ? _pickedBayLabel(_pickedBayIdForAny!)
        : _bayTitleForMode(_bayMode);

    final pickedLineColor =
        (_bayMode == _BayMode.any && _pickedBayIdForAny != null)
        ? _pickedBayColor(_pickedBayIdForAny!)
        : _bayColorForMode(_bayMode);

    return Scaffold(
      appBar: AppBar(title: const Text('Создать запись')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: safeCarId,
                decoration: const InputDecoration(
                  labelText: 'Авто',
                  border: OutlineInputBorder(),
                ),
                items: _cars
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(_carTitleForUi(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => carId = v),
                validator: (_) {
                  if (_cars.isEmpty) return 'Сначала добавь авто';
                  if (carId == null) return 'Выбери авто';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: safeServiceId,
                decoration: const InputDecoration(
                  labelText: 'Услуга',
                  border: OutlineInputBorder(),
                ),
                items: _services
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(
                          '${s.name} (${s.priceRub} ₽) • ${s.durationMin ?? 30} мин',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  setState(() {
                    serviceId = v;
                    _selectedSlotStart = null;
                    _pickedBayIdForAny = null;
                  });
                  await _refreshBusy(force: true);
                },
                validator: (_) {
                  if (_services.isEmpty) return 'Нет услуг';
                  if (serviceId == null) return 'Выбери услугу';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ✅ вертикальный выбор линии с цветной полоской
              _lineSelector(),

              const SizedBox(height: 12),

              // даты как и было, но подчёркиваем розовым
              Row(
                children: [
                  ChoiceChip(
                    label: Text(_chipLabelForDate(today)),
                    labelPadding: chipLabelPadding,
                    selected: _selectedDate == today,
                    selectedColor: _pink.withValues(alpha: 0.25),
                    onSelected: (_) => _selectDate(today),
                    visualDensity: chipVD,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(_chipLabelForDate(tomorrow)),
                    labelPadding: chipLabelPadding,
                    selected: _selectedDate == tomorrow,
                    selectedColor: _pink.withValues(alpha: 0.25),
                    onSelected: (_) => _selectDate(tomorrow),
                    visualDensity: chipVD,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        children: scrollDates.map((d) {
                          final dd = _dateOnly(d);
                          final selected = dd == _selectedDate;
                          final key = _keyForDate(dd);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              key: key,
                              child: ChoiceChip(
                                label: Text(_chipLabelForDate(dd)),
                                labelPadding: chipLabelPadding,
                                selected: selected,
                                selectedColor: _pink.withValues(alpha: 0.25),
                                onSelected: (_) => _selectDate(dd),
                                visualDensity: chipVD,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (visibleSlots.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text('В этот день нет свободного времени'),
                  ),
                )
              else ...[
                // ✅ секции как в yclients
                _timeSection(
                  title: 'Утро',
                  slots: morningSlots,
                  initiallyExpanded: true,
                ),
                _timeSection(
                  title: 'День',
                  slots: daySlots,
                  initiallyExpanded: true,
                ),
                _timeSection(
                  title: 'Вечер',
                  slots: eveningSlots,
                  initiallyExpanded: true,
                ),
              ],

              const SizedBox(height: 10),

              TextFormField(
                controller: _commentCtrl,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (по желанию)',
                  hintText:
                      'Например: машина в плёнке, арки под давлением не мыть…',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Оплата брони: $_depositRub ₽',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Остаток к оплате на месте: $remaining ₽',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: pickedLineColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Линия: $pickedLineText',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canProceed ? _save : null,
                  icon: const Icon(Icons.credit_card),
                  label: Text(_saving ? 'Сохраняю...' : 'Продолжить к оплате'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
