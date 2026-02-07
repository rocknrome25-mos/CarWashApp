// C:\dev\carwash\client_module\lib\features\bookings\create_booking_page.dart
// (FULL FILE — anti spam: multi-booking + waitlist lock + yandex-ish bottom CTA + reliable waitlist detection via ApiException.raw)

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/api/api_client.dart'; // ✅ ApiException (for raw/details)
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import '../../core/realtime/realtime_client.dart';
import 'payment_page.dart';

enum _BayMode { any, bay1, bay2 }
enum _DayPart { morning, day, evening }

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

  static const int _quickDaysTotal = 7;

  static const int _bufferMin = 15;
  static const int _depositRub = 500;

  static const Color _greenLine = Color(0xFF2DBD6E);
  static const Color _blueLine = Color(0xFF2D9CDB);

  List<LocationLite> _locations = const [];
  LocationLite? _location;

  List<Car> _cars = const [];
  List<Service> _services = const [];

  Map<int, List<DateTimeRange>> _busyByBay = const {1: [], 2: []};

  String? carId;
  String? serviceId;

  _BayMode _bayMode = _BayMode.any;

  DateTime _selectedDate = _dateOnly(DateTime.now());
  DateTime? _selectedSlotStart;

  int? _pickedBayIdForAny;

  final _commentCtrl = TextEditingController();

  bool _loading = true;
  Object? _error;
  bool _saving = false;

  bool _didInitialAutoPick = false;

  StreamSubscription<BookingRealtimeEvent>? _rtSub;

  final Set<String> _selectedAddonServiceIds = <String>{};

  // ✅ “Яндекс”: свайп машин
  final PageController _carsPage = PageController(viewportFraction: 1.0);

  // ✅ анти-спам waitlist: если уже поставили в ожидание — блокируем UI и кнопку
  bool _waitlistLocked = false;
  String? _waitlistLockedReason; // текст для UI

  bool get _uiLocked => _saving || _waitlistLocked;

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
      if (ev.type != 'booking.changed') return;

      // если мы в waitlist lock — всё равно обновим busy, но не дергаем выбор
      await _refreshBusy(force: true);
      if (!mounted) return;

      final cur = _selectedSlotStart;
      if (!_uiLocked && cur != null && _isBusySlot(cur)) {
        setState(() {
          _selectedSlotStart = null;
          _pickedBayIdForAny = null;
        });
        await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _carsPage.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ---------------- helpers ----------------

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  _DayPart _currentDayPart() {
    final h = DateTime.now().hour;
    if (h < 12) return _DayPart.morning;
    if (h < 17) return _DayPart.day;
    return _DayPart.evening;
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

  int _addonsTotalDurationMin() {
    int sum = 0;
    for (final sid in _selectedAddonServiceIds) {
      final s = _findService(sid);
      if (s == null) continue;
      final d = s.durationMin;
      if (d != null && d > 0) sum += d;
    }
    return sum;
  }

  int _addonsTotalPriceRub() {
    int sum = 0;
    for (final sid in _selectedAddonServiceIds) {
      final s = _findService(sid);
      if (s == null) continue;
      sum += s.priceRub;
    }
    return sum;
  }

  int _effectiveBlockMinForSelectedService() {
    final base = _serviceDurationOrDefault(serviceId);
    final addon = _addonsTotalDurationMin();
    final raw = base + addon + _bufferMin;
    return _roundUpToStepMin(raw, _slotStepMin);
  }

  int _washTimeMinApprox() {
    final base = _serviceDurationOrDefault(serviceId);
    final addon = _addonsTotalDurationMin();
    return max(base + addon, 0);
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

  DateTime _minSelectableNowLocal() {
    final now = DateTime.now();
    final lead = now.add(const Duration(minutes: _minLeadMin));
    return _ceilToStep(lead, _slotStepMin);
  }

  bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
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

  /// what client *requested*
  /// - any => null
  /// - bay1 => 1
  /// - bay2 => 2
  int? _requestedBayIdOrNull() {
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
    if (bayId != null) return _isBusySlotForBay(slotStart, bayId);
    final busy1 = _isBusySlotForBay(slotStart, 1);
    final busy2 = _isBusySlotForBay(slotStart, 2);
    return busy1 && busy2;
  }

  bool _endsBeforeClose(DateTime slotStart) {
    final blockMin = _effectiveBlockMinForSelectedService();
    final end = slotStart.add(Duration(minutes: blockMin));
    final close = DateTime(slotStart.year, slotStart.month, slotStart.day, _closeHour, 0);
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

  Color _hexToColorSafe(String hex, {Color fallback = const Color(0xFF2D9CDB)}) {
    final s = hex.trim();
    if (s.isEmpty) return fallback;
    var h = s;
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    if (v == null) return fallback;
    return Color(v);
  }

  void _lockWaitlistUi(String reason) {
    if (!mounted) return;
    setState(() {
      _waitlistLocked = true;
      _waitlistLockedReason = reason.trim().isEmpty ? null : reason.trim();
    });
  }

  // ✅ RELIABLE WAITLIST DETECTION (ApiClient humanizes message, so we check raw/details)
  bool _isWaitlistedException(Object e) {
    try {
      if (e is ApiException) {
        final raw = (e.raw ?? '').toString().toUpperCase();
        if (raw.contains('ALL_BAYS_CLOSED_WAITLISTED')) return true;
        if (raw.contains('BAY_CLOSED_WAITLISTED')) return true;

        final details = e.details;
        if (details is Map) {
          final msg = (details['message'] ?? '').toString().toUpperCase();
          if (msg.contains('ALL_BAYS_CLOSED_WAITLISTED')) return true;
          if (msg.contains('BAY_CLOSED_WAITLISTED')) return true;
        }

        // sometimes ApiException.message itself might still contain marker
        final m = e.message.toUpperCase();
        if (m.contains('ALL_BAYS_CLOSED_WAITLISTED')) return true;
        if (m.contains('BAY_CLOSED_WAITLISTED')) return true;
      }

      final s = e.toString().toUpperCase();
      if (s.contains('ALL_BAYS_CLOSED_WAITLISTED')) return true;
      if (s.contains('BAY_CLOSED_WAITLISTED')) return true;
    } catch (_) {}

    return false;
  }
  // ---------------- MULTI-BOOKING GUARD (client-side) ----------------

  int _addonsDurationFromBookingSafe(Booking b) {
    try {
      final dyn = b as dynamic;
      final addons = dyn.addons;
      if (addons is List) {
        int sum = 0;
        for (final x in addons) {
          int qty = 1;
          int dur = 0;

          if (x is Map) {
            final q = x['qty'];
            if (q is num && q.toInt() > 0) qty = q.toInt();
            final d = x['durationMinSnapshot'];
            if (d is num && d.toInt() > 0) dur = d.toInt();
          } else {
            try {
              final dx = x as dynamic;
              final q = dx.qty;
              if (q is num && q.toInt() > 0) qty = q.toInt();
              final d = dx.durationMinSnapshot;
              if (d is num && d.toInt() > 0) dur = d.toInt();
            } catch (_) {}
          }

          sum += qty * dur;
        }
        return max(sum, 0);
      }
    } catch (_) {}
    return 0;
  }

  int _blockMinForExistingBooking(Booking b) {
    final base = _serviceDurationOrDefault(b.serviceId);
    final addonSum = _addonsDurationFromBookingSafe(b);

    int buf = 0;
    try {
      final dyn = b as dynamic;
      final v = dyn.bufferMin;
      if (v is num && v.toInt() >= 0) buf = v.toInt();
    } catch (_) {}

    final raw = base + addonSum + buf;
    return _roundUpToStepMin(raw, _slotStepMin);
  }

  bool _isBookingStillBlocking(Booking b) {
    if (b.status == BookingStatus.active) return true;
    if (b.status == BookingStatus.pendingPayment) {
      final due = b.paymentDueAt;
      if (due == null) return true;
      return due.isAfter(DateTime.now());
    }
    return false;
  }

  Future<bool> _hasClientOverlapForSelectedSlot(DateTime slotStart) async {
    final blockMin = _effectiveBlockMinForSelectedService();
    final slotEnd = slotStart.add(Duration(minutes: blockMin));

    final list = await widget.repo.getBookings(
      includeCanceled: true,
      forceRefresh: true,
    );

    for (final b in list) {
      if (!_isBookingStillBlocking(b)) continue;
      if (b.status == BookingStatus.canceled || b.status == BookingStatus.completed) continue;

      final bStart = b.dateTime.toLocal();
      final bEnd = bStart.add(Duration(minutes: _blockMinForExistingBooking(b)));

      if (_overlaps(slotStart, slotEnd, bStart, bEnd)) {
        return true;
      }
    }

    return false;
  }

  // ✅ if client already has WAITING waitlist overlapping => block spam
  Future<bool> _hasClientWaitlistOverlapForSelectedSlot(DateTime slotStart) async {
    final cid = widget.repo.currentClient?.id.trim() ?? '';
    if (cid.isEmpty) return false;

    final blockMin = _effectiveBlockMinForSelectedService();
    final slotEnd = slotStart.add(Duration(minutes: blockMin));

    try {
      final list = await widget.repo.getWaitlist(
        clientId: cid,
        includeAll: false,
      );

      for (final w in list) {
        final iso = (w['desiredDateTime'] ?? w['dateTime'] ?? '').toString().trim();
        final dt = DateTime.tryParse(iso)?.toLocal();
        if (dt == null) continue;

        // duration for waitlist: service.duration + buffer(15) rounded to 30
        final dur = (w['service']?['durationMin'] as num?)?.toInt() ?? 30;
        final wlBlock = _roundUpToStepMin(dur + _bufferMin, _slotStepMin);
        final wlEnd = dt.add(Duration(minutes: wlBlock));

        if (_overlaps(slotStart, slotEnd, dt, wlEnd)) {
          return true;
        }
      }
    } catch (_) {
      // ignore
    }

    return false;
  }

  // ---------------- auto-pick slot logic ----------------

  Future<void> _autoPickBestSlotForCurrentState({required bool forceBusyRefresh}) async {
    if (_location == null) return;

    if (forceBusyRefresh) {
      await _refreshBusy(force: true);
      if (!mounted) return;
    }

    final cur = _selectedSlotStart;
    if (cur != null && !_isBusySlot(cur) && _endsBeforeClose(cur)) {
      if (_bayMode == _BayMode.any) {
        final bay = await _pickBayForSlotAny(cur);
        if (!mounted) return;
        setState(() => _pickedBayIdForAny = bay);
      }
      return;
    }

    final picked = _firstFreeSlotForDay(_selectedDate);
    if (!mounted) return;

    setState(() {
      _selectedSlotStart = picked;
      _pickedBayIdForAny = null;
    });

    if (picked != null && _bayMode == _BayMode.any) {
      final bay = await _pickBayForSlotAny(picked);
      if (!mounted) return;
      setState(() => _pickedBayIdForAny = bay);
    }
  }

  // ---------------- data loads ----------------

  Future<void> _refreshBusy({bool force = false}) async {
    final locId = _location?.id;
    if (locId == null || locId.trim().isEmpty) return;

    final day = _selectedDate;
    final from = DateTime(day.year, day.month, day.day, _openHour, 0);
    final to = DateTime(day.year, day.month, day.day, _closeHour, 0);

    final results = await Future.wait<List<DateTimeRange>>([
      widget.repo.getBusySlots(
        locationId: locId,
        bayId: 1,
        from: from,
        to: to,
        forceRefresh: force,
      ),
      widget.repo.getBusySlots(
        locationId: locId,
        bayId: 2,
        from: from,
        to: to,
        forceRefresh: force,
      ),
    ]);

    if (!mounted) return;
    setState(() => _busyByBay = {1: results[0], 2: results[1]});

    final cur = _selectedSlotStart;
    if (cur != null && _bayMode == _BayMode.any && !_isBusySlot(cur)) {
      final bay = await _pickBayForSlotAny(cur);
      if (!mounted) return;
      setState(() => _pickedBayIdForAny = bay);
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _waitlistLocked = false;
      _waitlistLockedReason = null;
    });

    try {
      final results = await Future.wait([
        widget.repo.getLocations(forceRefresh: true),
        widget.repo.getCars(forceRefresh: true),
        widget.repo.getServices(forceRefresh: true),
      ]);

      final locations = results[0] as List<LocationLite>;
      final cars = results[1] as List<Car>;
      final services = results[2] as List<Service>;

      LocationLite? selectedLoc = widget.repo.currentLocation;
      if (selectedLoc == null || selectedLoc.id.trim().isEmpty) {
        selectedLoc = locations.isNotEmpty ? locations.first : null;
        if (selectedLoc != null) {
          await widget.repo.setCurrentLocation(selectedLoc);
        }
      } else {
        if (!locations.any((x) => x.id == selectedLoc!.id)) {
          selectedLoc = locations.isNotEmpty ? locations.first : null;
          if (selectedLoc != null) {
            await widget.repo.setCurrentLocation(selectedLoc);
          }
        }
      }

      final String? selectedCarId = cars.isNotEmpty ? cars.first.id : null;

      String? selectedServiceId =
          widget.preselectedServiceId ?? (services.isNotEmpty ? services.first.id : null);
      if (widget.preselectedServiceId != null &&
          !services.any((s) => s.id == widget.preselectedServiceId)) {
        selectedServiceId = services.isNotEmpty ? services.first.id : null;
      }

      if (!mounted) return;

      setState(() {
        _locations = locations;
        _location = selectedLoc;

        _cars = cars;
        _services = services;

        carId = selectedCarId;
        serviceId = selectedServiceId;

        _selectedDate = _dateOnly(DateTime.now());
        _selectedSlotStart = null;
        _pickedBayIdForAny = null;

        _selectedAddonServiceIds.clear();

        _loading = false;
      });

      await _refreshBusy(force: true);

      if (!_didInitialAutoPick) {
        _didInitialAutoPick = true;
        await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _selectDate(DateTime d) async {
    if (_uiLocked) return;

    setState(() {
      _selectedDate = _dateOnly(d);
      _selectedSlotStart = null;
      _pickedBayIdForAny = null;
    });

    await _refreshBusy(force: true);
    await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
  }

  List<DateTime> _quickDates() {
    final today = _dateOnly(DateTime.now());
    return List.generate(_quickDaysTotal, (i) => today.add(Duration(days: i)));
  }

  String _weekdayShortRu(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'ПН';
      case DateTime.tuesday:
        return 'ВТ';
      case DateTime.wednesday:
        return 'СР';
      case DateTime.thursday:
        return 'ЧТ';
      case DateTime.friday:
        return 'ПТ';
      case DateTime.saturday:
        return 'СБ';
      case DateTime.sunday:
        return 'ВС';
    }
    return '';
  }
  // ---------------- UI: cars (FULL WIDTH, swipe like Yandex) ----------------

  String _carIconAsset(Car c) {
    final bt = (c.bodyType ?? '').toLowerCase().trim();
    final title = c.title.toLowerCase();
    final hint = '$bt $title';
    const base = 'assets/images/cars';

    if (hint.contains('suv') ||
        hint.contains('внедорож') ||
        hint.contains('крос') ||
        hint.contains('джип')) {
      return '$base/suv.png';
    }
    if (hint.contains('sedan') || hint.contains('седан')) {
      return '$base/sedan.png';
    }
    return '$base/incognito.png';
  }

  Widget _carTile(Car c, {required bool selected}) {
    final cs = Theme.of(context).colorScheme;

    final borderColor = selected
        ? cs.primary.withValues(alpha: 0.65)
        : cs.outlineVariant.withValues(alpha: 0.55);

    final bg = selected
        ? cs.primary.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest.withValues(alpha: 0.16);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: _uiLocked ? null : () => setState(() => carId = c.id),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Align(
                alignment: const Alignment(0, 0.15),
                child: Image.asset(
                  _carIconAsset(c),
                  width: 320,
                  height: 140,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.directions_car,
                    size: 60,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title.trim().isEmpty ? 'Авто' : c.title.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      c.plateDisplay,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carsSelector() {
    final cs = Theme.of(context).colorScheme;

    if (_cars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Text(
          'Сначала добавь авто в профиле.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.80),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final selectedId = carId ?? _cars.first.id;
    final selectedIndex = max(0, _cars.indexWhere((c) => c.id == selectedId));
    if (selectedIndex >= 0 && selectedIndex < _cars.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _carsPage.jumpToPage(selectedIndex);
        } catch (_) {}
      });
    }

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _carsPage,
        itemCount: _cars.length,
        onPageChanged: (i) {
          if (_uiLocked) return;
          if (i >= 0 && i < _cars.length) {
            setState(() => carId = _cars[i].id);
          }
        },
        itemBuilder: (_, i) {
          final c = _cars[i];
          return _carTile(c, selected: c.id == (carId ?? _cars.first.id));
        },
      ),
    );
  }

  // ---------------- UI: date squares ----------------

  Widget _dateSquare(DateTime d) {
    final cs = Theme.of(context).colorScheme;
    final dd = _dateOnly(d);
    final selected = dd == _selectedDate;

    final bg = selected
        ? cs.primary.withValues(alpha: 0.20)
        : cs.surfaceContainerHighest.withValues(alpha: 0.14);
    final border = selected
        ? cs.primary.withValues(alpha: 0.65)
        : cs.outlineVariant.withValues(alpha: 0.55);

    final top = _weekdayShortRu(dd.weekday);
    final day = dd.day.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _uiLocked ? null : () => _selectDate(dd),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Text(
              top,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI: bay selector row ----------------

  Future<void> _selectBay(_BayMode mode) async {
    if (_uiLocked) return;
    setState(() {
      _bayMode = mode;
      _pickedBayIdForAny = null;
    });
    await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
  }

  String _bayTitleForMode(_BayMode m) {
    switch (m) {
      case _BayMode.any:
        return 'Любая линия';
      case _BayMode.bay1:
        return 'Зелёная';
      case _BayMode.bay2:
        return 'Синяя';
    }
  }

  Color _bayStripeColor(BuildContext context, _BayMode m) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (m) {
      case _BayMode.any:
        return primary;
      case _BayMode.bay1:
        return _greenLine;
      case _BayMode.bay2:
        return _blueLine;
    }
  }

  String _bayIconAsset(_BayMode mode) {
    switch (mode) {
      case _BayMode.any:
        return 'assets/images/posts/post_any.png';
      case _BayMode.bay1:
        return 'assets/images/posts/post_green.png';
      case _BayMode.bay2:
        return 'assets/images/posts/post_blue.png';
    }
  }

  Widget _bayIcon(_BayMode mode, Color fallbackColor) {
    return Image.asset(
      _bayIconAsset(mode),
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: fallbackColor,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _lineSelectorRow() {
    final cs = Theme.of(context).colorScheme;

    Widget item(_BayMode mode, {required int flex}) {
      final selected = _bayMode == mode;
      final stripe = _bayStripeColor(context, mode);

      return Expanded(
        flex: flex,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _uiLocked ? null : () => _selectBay(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? stripe.withValues(alpha: 0.12)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? stripe.withValues(alpha: 0.70)
                    : cs.outlineVariant.withValues(alpha: 0.60),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: stripe,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                _bayIcon(mode, stripe),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _bayTitleForMode(mode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, color: stripe, size: 18),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item(_BayMode.any, flex: 2),
        const SizedBox(width: 10),
        item(_BayMode.bay1, flex: 1),
        const SizedBox(width: 10),
        item(_BayMode.bay2, flex: 1),
      ],
    );
  }

  // ---------------- UI: addons ----------------

  List<Service> _addonCandidates() {
    final sid = serviceId;
    final list = _services.where((s) => sid == null ? true : s.id != sid).toList();
    list.sort((a, b) => a.priceRub.compareTo(b.priceRub));
    return list;
  }

  List<Map<String, dynamic>> _addonsPayload() {
    final out = <Map<String, dynamic>>[];
    for (final sid in _selectedAddonServiceIds) {
      out.add({'serviceId': sid, 'qty': 1});
    }
    return out;
  }

  Future<void> _toggleAddon(Service s, bool value) async {
    if (_uiLocked) return;

    setState(() {
      if (value) {
        _selectedAddonServiceIds.add(s.id);
      } else {
        _selectedAddonServiceIds.remove(s.id);
      }
    });

    await _refreshBusy(force: true);
    await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
  }

  Widget _addonMetaPill(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: cs.onSurface.withValues(alpha: 0.92),
        ),
      ),
    );
  }

  Widget _addonRow(Service s, {bool dense = false}) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedAddonServiceIds.contains(s.id);

    final dur = (s.durationMin ?? 0);
    final price = s.priceRub;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _addonMetaPill('$price ₽'),
                    _addonMetaPill('+$dur мин'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: selected,
            onChanged: _uiLocked ? null : (v) => _toggleAddon(s, v),
          ),
        ],
      ),
    );
  }

  Future<void> _openAllAddonsSheet() async {
    final list = _addonCandidates();
    if (list.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Дополнительные услуги',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _addonRow(list[i]),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addonsSection() {
    final list = _addonCandidates();
    if (list.isEmpty) return const SizedBox.shrink();

    final preview = list.take(2).toList();
    final totalDur = _addonsTotalDurationMin();
    final totalPrice = _addonsTotalPriceRub();

    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Дополнительные услуги',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          for (final s in preview) ...[
            _addonRow(s, dense: true),
            const SizedBox(height: 10),
          ],
          if (list.length > 2)
            Center(
              child: TextButton(
                onPressed: _uiLocked ? null : _openAllAddonsSheet,
                child: const Text('Посмотреть все'),
              ),
            ),
          if (totalDur > 0 || totalPrice > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Выбрано: +$totalDur мин • +$totalPrice ₽',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
  // ---------------- UI: time ----------------

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

  List<DateTime> _filterByHourRange(List<DateTime> slots, int fromHour, int toHourExclusive) {
    return slots.where((d) => d.hour >= fromHour && d.hour < toHourExclusive).toList();
  }

  ButtonStyle _slotStyleOutlined() {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.styleFrom(
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: const StadiumBorder(),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  ButtonStyle _slotStyleFilled() {
    final primary = Theme.of(context).colorScheme.primary;
    return FilledButton.styleFrom(
      backgroundColor: primary,
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
      if (_uiLocked) return;
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
            onPressed: _uiLocked ? null : select,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          )
        : OutlinedButton(
            style: _slotStyleOutlined(),
            onPressed: _uiLocked ? null : select,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          );
  }

  Widget _timeSection({
    required String title,
    required List<DateTime> slots,
    required bool initiallyExpanded,
  }) {
    if (slots.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
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

  // ---------------- WAITLIST dialog ----------------

  Future<void> _showWaitlistDialogAndGoToBookings() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Посты сейчас закрыты'),
        content: const Text(
          'Мы добавили вас в очередь ожидания.\nКак только появится возможность — свяжемся с вами.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop('waitlisted'); // parent should switch to Bookings tab
  }

  // ---------------- SAVE ----------------

  Future<void> _save() async {
    if (_uiLocked) return;
    if (_location == null) return;

    if (_cars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала добавь авто.')));
      return;
    }
    if (carId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выбери авто.')));
      return;
    }
    if (serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выбери услугу.')));
      return;
    }

    final slot = _selectedSlotStart;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выбери время.')));
      return;
    }

    final isToday = _selectedDate == _dateOnly(DateTime.now());
    final minNow = _minSelectableNowLocal();
    if (isToday && slot.isBefore(minNow)) return;
    if (_isBusySlot(slot)) return;

    // ✅ (1) client-level overlap guard (bookings)
    try {
      final hasOverlap = await _hasClientOverlapForSelectedSlot(slot);
      if (!mounted) return;
      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('У вас уже есть запись на это время. Выберите другое время или отмените текущую запись.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } catch (_) {}

    // ✅ (2) waitlist overlap guard (WAITING)
    try {
      final hasWait = await _hasClientWaitlistOverlapForSelectedSlot(slot);
      if (!mounted) return;
      if (hasWait) {
        _lockWaitlistUi('У вас уже есть заявка в ожидании на это время.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('У вас уже есть заявка в ожидании. Перейдите в “Записи”.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } catch (_) {}

    int? bayIdToSend = _currentBayIdOrNull();
    if (bayIdToSend == null) {
      bayIdToSend = _pickedBayIdForAny;
      bayIdToSend ??= await _pickBayForSlotAny(slot);
      if (!mounted) return;

      if (bayIdToSend == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступной линии на это время. Выбери другое.')),
        );
        return;
      }
    }

    final requestedBayId = _requestedBayIdOrNull(); // null means ANY
    setState(() => _saving = true);

    try {
      final addonsPayload = _addonsPayload();

      final Booking booking = await widget.repo.createBooking(
        locationId: _location!.id,
        carId: carId!,
        serviceId: serviceId!,
        dateTime: slot,
        bayId: bayIdToSend,
        requestedBayId: requestedBayId,
        depositRub: _depositRub,
        bufferMin: _bufferMin,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        addons: addonsPayload.isEmpty ? null : addonsPayload,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись создана, но не оплачена.')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // ✅ reliable waitlist recognition
      if (_isWaitlistedException(e)) {
        _lockWaitlistUi('Посты сейчас закрыты. Вы добавлены в очередь ожидания.');
        await _showWaitlistDialogAndGoToBookings();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canProceed() {
    if (_uiLocked) return false;
    if (_location == null) return false;
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

  // ---------------- UI blocks ----------------

  Widget _sectionCard({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String t) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.90),
            ),
      ),
    );
  }

  Widget _pill(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
      ),
    );
  }

  Widget _waitlistLockedBanner() {
    final cs = Theme.of(context).colorScheme;
    final t = _waitlistLockedReason ?? 'Вы уже в очереди ожидания.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.90),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomCtaBar({required bool canProceed, required int remainingRub}) {
    // ✅ if waitlisted => show “go to bookings”
    if (_waitlistLocked) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _waitlistLockedBanner(),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('waitlisted'),
                  icon: const Icon(Icons.event_note),
                  label: const Text('Перейти к записям'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canProceed ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.credit_card),
            label: Text(
              _saving ? 'Сохраняю...' : 'Продолжить к оплате • $remainingRub ₽',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Записаться на мойку')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Записаться на мойку')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ошибка: $_error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _bootstrap, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    final serviceIds = _services.map((s) => s.id).toSet();
    final safeServiceId = (serviceId != null && serviceIds.contains(serviceId)) ? serviceId : null;

    final dates = _quickDates();

    final service = _findService(safeServiceId);
    final basePriceRub = service?.priceRub ?? 0;
    final addonsPriceRub = _addonsTotalPriceRub();
    final totalPriceRub = basePriceRub + addonsPriceRub;
    final remaining = max(totalPriceRub - _depositRub, 0);

    final visibleSlots = _visibleSlotsForCurrentMode();
    final morningSlots = _filterByHourRange(visibleSlots, _openHour, 12);
    final daySlots = _filterByHourRange(visibleSlots, 12, 17);
    final eveningSlots = _filterByHourRange(visibleSlots, 17, _closeHour);

    final canProceed = _canProceed();
    final nowPart = _currentDayPart();

    String pickedLineText;
    if (_bayMode == _BayMode.any && _pickedBayIdForAny != null) {
      pickedLineText = _pickedBayIdForAny == 1 ? 'Зелёная линия' : 'Синяя линия';
    } else {
      pickedLineText = _bayMode == _BayMode.any
          ? 'Любая линия'
          : (_bayMode == _BayMode.bay1 ? 'Зелёная линия' : 'Синяя линия');
    }

    final pickedLineColor = _bayStripeColor(context, _bayMode);

    final loc = _location;
    final locColor = _hexToColorSafe(loc?.colorHex ?? '#2D9CDB');

    return Scaffold(
      appBar: AppBar(title: const Text('Записаться на мойку')),
      bottomNavigationBar: _bottomCtaBar(canProceed: canProceed, remainingRub: remaining),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: ListView(
          children: [
            if (_locations.isNotEmpty) ...[
              _sectionTitle('Мойка по адресу'),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: loc?.id,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _locations.map((l) {
                        final c = _hexToColorSafe(l.colorHex);
                        return DropdownMenuItem<String>(
                          value: l.id,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${l.name} — ${l.address}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _uiLocked
                          ? null
                          : (id) async {
                              if (id == null) return;
                              final picked = _locations.firstWhere((x) => x.id == id);
                              await widget.repo.setCurrentLocation(picked);
                              if (!mounted) return;

                              setState(() {
                                _location = picked;
                                _selectedSlotStart = null;
                                _pickedBayIdForAny = null;
                              });

                              await _refreshBusy(force: true);
                              await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
                            },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: locColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Проверь, что выбран правильный адрес мойки.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.70),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _sectionTitle('Авто'),
            _sectionCard(child: _carsSelector()),
            const SizedBox(height: 12),

            _sectionTitle('Услуга'),
            _sectionCard(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: safeServiceId,
                decoration: const InputDecoration(
                  labelText: 'Тариф',
                  border: OutlineInputBorder(),
                ),
                items: _services
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text('${s.name} (${s.priceRub} ₽) • ${s.durationMin ?? 30} мин'),
                      ),
                    )
                    .toList(),
                onChanged: _uiLocked
                    ? null
                    : (v) async {
                        setState(() {
                          serviceId = v;
                          _selectedSlotStart = null;
                          _pickedBayIdForAny = null;
                          _selectedAddonServiceIds.clear();
                        });
                        await _refreshBusy(force: true);
                        await _autoPickBestSlotForCurrentState(forceBusyRefresh: false);
                      },
              ),
            ),

            const SizedBox(height: 12),
            _addonsSection(),
            const SizedBox(height: 12),

            _sectionTitle('Линия'),
            _sectionCard(child: _lineSelectorRow()),
            const SizedBox(height: 12),

            _sectionTitle('Дата'),
            _sectionCard(
              child: SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: dates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _dateSquare(dates[i]),
                ),
              ),
            ),

            const SizedBox(height: 12),
            _sectionTitle('Время'),
            _sectionCard(
              child: (visibleSlots.isEmpty)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'В этот день нет свободного времени',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.80),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _timeSection(
                          title: 'Утро',
                          slots: morningSlots,
                          initiallyExpanded: nowPart == _DayPart.morning,
                        ),
                        _timeSection(
                          title: 'День',
                          slots: daySlots,
                          initiallyExpanded: nowPart == _DayPart.day,
                        ),
                        _timeSection(
                          title: 'Вечер',
                          slots: eveningSlots,
                          initiallyExpanded: nowPart == _DayPart.evening,
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 12),
            _sectionTitle('Комментарий'),
            _sectionCard(
              child: TextFormField(
                controller: _commentCtrl,
                enabled: !_uiLocked,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий (по желанию)',
                  hintText: 'Например: машина в плёнке, арки под давлением не мыть…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const SizedBox(height: 12),
            _sectionTitle('Итого'),
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Расчётное время на мойке ~${_washTimeMinApprox()} мин',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withValues(alpha: 0.92),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pill(cs, 'Депозит: $_depositRub ₽'),
                      _pill(cs, 'К оплате: $remaining ₽'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: pickedLineColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickedLineText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface.withValues(alpha: 0.78),
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Длительность слота: ${_effectiveBlockMinForSelectedService()} мин (с запасом $_bufferMin минут)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Стоимость: $totalPriceRub ₽',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: locColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Выбранная мойка: ${loc?.name ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface.withValues(alpha: 0.78),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80), // место под bottom bar
          ],
        ),
      ),
    );
  }
}
