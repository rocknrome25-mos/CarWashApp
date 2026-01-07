import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import 'payment_page.dart';

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
  static const int _quickPinnedDays = 2; // Сегодня + Завтра(датой)

  final _formKey = GlobalKey<FormState>();
  final Map<DateTime, GlobalKey> _dateKeys = {};

  List<Car> _cars = const [];
  List<Service> _services = const [];
  List<Booking> _bookings = const [];

  String? carId;
  String? serviceId;

  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime? _selectedSlotStart;

  bool _loading = true;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
    if (diff < _quickPinnedDays) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dateKeys[dd];
      final ctx = key?.currentContext;
      if (ctx == null) {
        return;
      }

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

  String _fmtDateShort(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}';
  }

  String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
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

  bool _overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  DateTime _minSelectableNowLocal() {
    final now = DateTime.now();
    final lead = now.add(const Duration(minutes: _minLeadMin));
    return _ceilToStep(lead, _slotStepMin);
  }

  bool _isBusySlot(DateTime slotStart, int selectedServiceMin) {
    final slotEnd = slotStart.add(Duration(minutes: selectedServiceMin));
    final now = DateTime.now();

    final busy = _bookings.where((b) {
      if (b.status == BookingStatus.active) return true;

      if (b.status == BookingStatus.pendingPayment) {
        final due = b.paymentDueAt;
        if (due == null) return false;
        return due.isAfter(now);
      }

      return false;
    });

    for (final b in busy) {
      final dur = _serviceDurationOrDefault(b.serviceId);
      final bStart = b.dateTime.toLocal();
      final bEnd = bStart.add(Duration(minutes: dur));
      if (_overlaps(slotStart, slotEnd, bStart, bEnd)) return true;
    }
    return false;
  }

  bool _endsBeforeClose(DateTime slotStart, int selectedServiceMin) {
    final end = slotStart.add(Duration(minutes: selectedServiceMin));
    final close = DateTime(
      slotStart.year,
      slotStart.month,
      slotStart.day,
      _closeHour,
      0,
    );
    return !end.isAfter(close);
  }

  List<DateTime> _buildSlotsForDay(DateTime day, int selectedServiceMin) {
    final start = DateTime(day.year, day.month, day.day, _openHour, 0);
    final end = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final slots = <DateTime>[];
    var cur = start;

    while (cur.isBefore(end)) {
      if (_endsBeforeClose(cur, selectedServiceMin)) {
        slots.add(cur);
      }
      cur = cur.add(const Duration(minutes: _slotStepMin));
    }
    return slots;
  }

  DateTime? _firstFreeSlotForDay(DateTime day, int selectedServiceMin) {
    final slots = _buildSlotsForDay(day, selectedServiceMin);
    final minNow = _minSelectableNowLocal();
    final isToday = _dateOnly(day) == _dateOnly(DateTime.now());

    for (final s in slots) {
      if (isToday && s.isBefore(minNow)) continue;
      if (_isBusySlot(s, selectedServiceMin)) continue;
      return s;
    }
    return null;
  }

  void _autoPickSlot({bool force = false}) {
    final dur = _serviceDurationOrDefault(serviceId);

    if (!force && _selectedSlotStart != null) {
      final s = _selectedSlotStart!;
      final isSameDay = _dateOnly(s) == _selectedDate;
      if (isSameDay) {
        final minNow = _minSelectableNowLocal();
        final isToday = _selectedDate == _dateOnly(DateTime.now());
        final tooEarly = isToday && s.isBefore(minNow);
        final busy = _isBusySlot(s, dur);
        if (!tooEarly && !busy) {
          return;
        }
      }
    }

    final picked = _firstFreeSlotForDay(_selectedDate, dur);
    if (picked != null) {
      _selectedSlotStart = picked;
      return;
    }

    for (var i = 1; i <= 7; i++) {
      final next = _selectedDate.add(Duration(days: i));
      final p = _firstFreeSlotForDay(next, dur);
      if (p != null) {
        _selectedDate = _dateOnly(next);
        _selectedSlotStart = p;
        return;
      }
    }

    _selectedSlotStart = null;
  }

  void _selectDate(DateTime d) {
    setState(() {
      _selectedDate = _dateOnly(d);
      _selectedSlotStart = null;
      _autoPickSlot(force: true);
    });
    _scrollDateIntoCenter(d);
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
    if (diff == 1) {
      return _fmtDateShort(d); // завтра = короткая дата
    }
    return _fmtDateShort(d);
  }

  int _slotColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 520) return 5;
    if (w >= 420) return 4;
    return 3;
  }

  ButtonStyle _slotStyleOutlined() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(0, 34),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  ButtonStyle _slotStyleFilled() {
    return FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(0, 34),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  Widget _slotLabel(String time, {String? badge}) {
    final timeW = Text(
      time,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
    );

    if (badge == null) return timeW;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        timeW,
        const SizedBox(height: 1),
        Text(
          badge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, height: 1.0),
        ),
      ],
    );
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
        widget.repo.getBookings(includeCanceled: true, forceRefresh: true),
      ]);

      final cars = results[0] as List<Car>;
      final services = results[1] as List<Service>;
      final bookings = results[2] as List<Booking>;

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
        _bookings = bookings;

        carId = selectedCarId;
        serviceId = selectedServiceId;

        _selectedDate = _dateOnly(DateTime.now());
        _selectedSlotStart = null;

        _loading = false;

        _autoPickSlot(force: true);
      });

      _scrollDateIntoCenter(_selectedDate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (carId == null || serviceId == null) return;

    final messenger = ScaffoldMessenger.of(context);

    final slot = _selectedSlotStart;
    if (slot == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Выбери слот времени')),
      );
      return;
    }

    final selectedServiceMin = _serviceDurationOrDefault(serviceId);

    final isToday = _selectedDate == _dateOnly(DateTime.now());
    final minNow = _minSelectableNowLocal();
    if (isToday && slot.isBefore(minNow)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Слишком рано. Выбери ближайший доступный слот.'),
        ),
      );
      return;
    }

    if (_isBusySlot(slot, selectedServiceMin)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Этот слот уже занят. Выбери другой.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final Booking booking = await widget.repo.createBooking(
        carId: carId!,
        serviceId: serviceId!,
        dateTime: slot,
      );

      if (!mounted) return;

      final service = _findService(serviceId);

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            repo: widget.repo,
            booking: booking,
            service: service,
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

    final selectedServiceMin = _serviceDurationOrDefault(safeServiceId);
    final slots = _buildSlotsForDay(_selectedDate, selectedServiceMin);

    final minNow = _minSelectableNowLocal();
    final isSelectedDayToday = _selectedDate == _dateOnly(DateTime.now());
    final cols = _slotColumns(context);

    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final scrollDates = _quickDatesScrollable();

    const chipLabelPadding = EdgeInsets.symmetric(horizontal: 10);
    const chipVD = VisualDensity(horizontal: -2, vertical: -2);

    return Scaffold(
      appBar: AppBar(title: const Text('Создать запись')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
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
                        child: Text('${c.make} ${c.model} (${c.plateDisplay})'),
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
                onChanged: (v) => setState(() {
                  serviceId = v;
                  _selectedSlotStart = null;
                  _autoPickSlot(force: true);
                }),
                validator: (_) {
                  if (_services.isEmpty) return 'Нет услуг';
                  if (serviceId == null) return 'Выбери услугу';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  ChoiceChip(
                    label: Text(_chipLabelForDate(today)),
                    labelPadding: chipLabelPadding,
                    selected: _selectedDate == today,
                    onSelected: (_) => _selectDate(today),
                    visualDensity: chipVD,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(_chipLabelForDate(tomorrow)),
                    labelPadding: chipLabelPadding,
                    selected: _selectedDate == tomorrow,
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

              const SizedBox(height: 10),

              const Row(
                children: [
                  Text('Время', style: TextStyle(fontWeight: FontWeight.w800)),
                  Spacer(),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: slots.isEmpty
                    ? const Center(child: Text('Нет слотов на выбранную дату'))
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.2,
                        ),
                        itemCount: slots.length,
                        itemBuilder: (context, i) {
                          final s = slots[i];

                          final tooEarly =
                              isSelectedDayToday && s.isBefore(minNow);
                          final busy = _isBusySlot(s, selectedServiceMin);
                          final disabled = tooEarly || busy;

                          final selected = _selectedSlotStart == s;
                          final time = _fmtTime(s);
                          final badge = busy
                              ? 'занято'
                              : (tooEarly ? 'рано' : null);

                          if (selected) {
                            return FilledButton(
                              style: _slotStyleFilled(),
                              onPressed: disabled
                                  ? null
                                  : () {
                                      setState(() => _selectedSlotStart = s);
                                    },
                              child: _slotLabel(time, badge: badge),
                            );
                          }

                          return OutlinedButton(
                            style: _slotStyleOutlined(),
                            onPressed: disabled
                                ? null
                                : () {
                                    setState(() => _selectedSlotStart = s);
                                  },
                            child: _slotLabel(time, badge: badge),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_cars.isEmpty || _services.isEmpty || _saving)
                      ? null
                      : _save,
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
