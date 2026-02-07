// C:\dev\carwash\client_module\lib\features\bookings\bookings_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import '../../widgets/empty_state.dart';
import 'booking_details_page.dart';
import 'waitlist_page.dart';

class BookingsPage extends StatefulWidget {
  final AppRepository repo;
  final int refreshToken;

  const BookingsPage({
    super.key,
    required this.repo,
    required this.refreshToken,
  });

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  static const Color _greenLine = Color(0xFF2DBD6E);
  static const Color _blueLine = Color(0xFF2D9CDB);

  late Future<_BookingsBundle> _future;

  StreamSubscription? _subRefresh; // repo.refresh$ (if exists)
  StreamSubscription? _subEvents; // repo.bookingEvents (always)
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = _load(force: false);
    _subscribeRefresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subRefresh?.cancel();
    _subEvents?.cancel();
    super.dispose();
  }

  void _subscribeRefresh() {
    _subRefresh?.cancel();
    _subEvents?.cancel();

    // 1) Prefer repo.refresh$ if exists (ApiRepository)
    try {
      final dyn = widget.repo as dynamic;
      final candidate = dyn.refresh$;
      if (candidate is Stream) {
        _subRefresh = candidate.listen((_) => _onAnyRefreshEvent());
      }
    } catch (_) {
      _subRefresh = null;
    }

    // 2) Always listen to bookingEvents as a safety net
    _subEvents = widget.repo.bookingEvents.listen((_) => _onAnyRefreshEvent());
  }

  void _onAnyRefreshEvent() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
    }
    if (oldWidget.repo != widget.repo) {
      _subscribeRefresh();
    }
  }

  Future<_BookingsBundle> _load({required bool force}) async {
    final res = await Future.wait([
      widget.repo.getBookings(includeCanceled: true, forceRefresh: force),
      widget.repo.getCars(forceRefresh: force),
      widget.repo.getServices(forceRefresh: force),
      _loadWaitlist(force: force),
    ]);

    return _BookingsBundle(
      bookings: res[0] as List<Booking>,
      cars: res[1] as List<Car>,
      services: res[2] as List<Service>,
      waitlist: res[3] as List<Map<String, dynamic>>,
    );
  }

  Future<List<Map<String, dynamic>>> _loadWaitlist({
    required bool force,
  }) async {
    final cid = widget.repo.currentClient?.id.trim() ?? '';
    if (cid.isEmpty) return const [];
    // NOTE: repo.getWaitlist currently doesn't use forceRefresh; ok for now
    return widget.repo.getWaitlist(clientId: cid, includeAll: false);
  }

  void _refresh() {
    setState(() {
      _future = _load(force: true);
    });
  }

  // ---------------- helpers ----------------

  DateTime _local(DateTime d) => d.toLocal();

  String _dateKey(DateTime d) {
    final x = _local(d);
    return '${x.year}-${x.month}-${x.day}';
  }

  String _dateHeader(DateTime d) {
    final x = _local(d);
    return '${x.day.toString().padLeft(2, '0')}.'
        '${x.month.toString().padLeft(2, '0')}.'
        '${x.year}';
  }

  String _time(DateTime d) {
    final x = _local(d);
    return '${x.hour.toString().padLeft(2, '0')}:'
        '${x.minute.toString().padLeft(2, '0')}';
  }

  String _dtInline(DateTime d) => '${_dateHeader(d)} • ${_time(d)}';

  int _addonsCountSafe(Booking b) {
    try {
      final dyn = b as dynamic;
      final addons = dyn.addons;
      if (addons is List) return addons.length;
    } catch (_) {}
    return 0;
  }

  Color _statusColor(BuildContext ctx, Booking b) {
    if (b.isWashing) return Colors.blue;
    final cs = Theme.of(ctx).colorScheme;
    switch (b.status) {
      case BookingStatus.active:
        return cs.primary;
      case BookingStatus.pendingPayment:
        return Colors.orange;
      case BookingStatus.completed:
        return Colors.grey;
      case BookingStatus.canceled:
        return Colors.red;
    }
  }

  String _statusText(Booking b) {
    if (b.isWashing) return 'МОЕТСЯ';
    switch (b.status) {
      case BookingStatus.active:
        return 'ЗАБРОНИРОВАНО';
      case BookingStatus.pendingPayment:
        return 'ОЖИДАЕТ ОПЛАТЫ';
      case BookingStatus.completed:
        return 'ЗАВЕРШЕНО';
      case BookingStatus.canceled:
        return 'ОТМЕНЕНО';
    }
  }

  Color _bayColor(BuildContext ctx, int? bayId) {
    if (bayId == 1) return _greenLine;
    if (bayId == 2) return _blueLine;
    return Theme.of(ctx).colorScheme.primary;
  }

  String _bayText(int? bayId) {
    if (bayId == 1) return 'Зелёная линия';
    if (bayId == 2) return 'Синяя линия';
    return 'Любая линия';
  }

  String _bayIcon(int? bayId) {
    if (bayId == 1) return 'assets/images/posts/post_green.png';
    if (bayId == 2) return 'assets/images/posts/post_blue.png';
    return 'assets/images/posts/post_any.png';
  }

  String _serviceImage(Service? s) {
    final name = (s?.name ?? '').toLowerCase();
    if (name.contains('комплекс'))
      return 'assets/images/services/kompleks_512.jpg';
    if (name.contains('воск')) return 'assets/images/services/vosk_512.jpg';
    return 'assets/images/services/kuzov_512.jpg';
  }

  int _effectivePriceRub(Service? s, Booking b) {
    final price = s?.priceRub ?? 0;
    return max(price - b.discountRub, 0);
  }

  int _toPayRub(Service? s, Booking b) {
    final total = _effectivePriceRub(s, b);
    return max(total - b.paidTotalRub, 0);
  }

  // ---------------- Yandex-like layers ----------------

  Widget _sectionBox({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }

  Widget _pill({required String text, IconData? icon, Color? borderTint}) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHighest.withValues(alpha: 0.22);
    final border = (borderTint ?? cs.outlineVariant).withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadgeText(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c),
      ),
    );
  }

  Widget _statusBadgeBooking(Booking b) {
    final c = _statusColor(context, b);
    return _statusBadgeText(_statusText(b), c);
  }

  Widget _serviceThumb(Service? s) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        _serviceImage(s),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.local_car_wash, color: cs.onSurface),
        ),
      ),
    );
  }

  Widget _bayRow(int? bayId) {
    final cs = Theme.of(context).colorScheme;
    final color = _bayColor(context, bayId);

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Image.asset(
          _bayIcon(bayId),
          width: 18,
          height: 18,
          errorBuilder: (_, __, ___) => Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _bayText(bayId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.90),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- unified list ----------------

  DateTime _waitlistDateTime(Map<String, dynamic> w) {
    final iso = (w['desiredDateTime'] ?? w['dateTime'] ?? '').toString().trim();
    final dt = DateTime.tryParse(iso);
    return (dt ?? DateTime.now()).toLocal();
  }

  int? _waitlistDesiredBay(Map<String, dynamic> w) {
    final v = w['desiredBayId'] ?? w['bayId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    final p = int.tryParse(v?.toString() ?? '');
    return p;
  }

  String _waitlistReason(Map<String, dynamic> w) {
    final raw = (w['reason'] ?? '').toString().trim();
    if (raw.isEmpty) return 'Ожидание свободного поста';
    final up = raw.toUpperCase();
    if (up.contains('ALL_BAYS_CLOSED')) return 'Посты закрыты';
    if (up.contains('BAY_CLOSED')) return 'Пост закрыт';
    return raw;
  }

  String _waitlistCarLine(Map<String, dynamic> w) {
    final make = (w['car']?['makeDisplay'] ?? '').toString().trim();
    final model = (w['car']?['modelDisplay'] ?? '').toString().trim();
    final plate = (w['car']?['plateDisplay'] ?? '').toString().trim();
    final parts = <String>[];
    final mm = ('$make $model').trim();
    if (mm.isNotEmpty) parts.add(mm);
    if (plate.isNotEmpty) parts.add('($plate)');
    return parts.join(' ');
  }

  String _waitlistServiceName(Map<String, dynamic> w) {
    final name = (w['service']?['name'] ?? '').toString().trim();
    return name.isEmpty ? 'Услуга' : name;
  }

  String _waitlistServiceImage(Map<String, dynamic> w) {
    final name = _waitlistServiceName(w).toLowerCase();
    if (name.contains('комплекс'))
      return 'assets/images/services/kompleks_512.jpg';
    if (name.contains('воск')) return 'assets/images/services/vosk_512.jpg';
    return 'assets/images/services/kuzov_512.jpg';
  }

  Widget _waitlistThumb(Map<String, dynamic> w) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        _waitlistServiceImage(w),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.hourglass_bottom, color: cs.onSurface),
        ),
      ),
    );
  }

  Widget _bookingCard({
    required Booking b,
    required Car? car,
    required Service? service,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final total = _effectivePriceRub(service, b);
    final toPay = _toPayRub(service, b);
    final addonsCount = _addonsCountSafe(b);
    final secondary = cs.onSurface.withValues(alpha: 0.72);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: _sectionBox(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _serviceThumb(service),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service?.name ?? 'Услуга удалена',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface.withValues(alpha: 0.92),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadgeBooking(b),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _pill(text: _dtInline(b.dateTime), icon: Icons.schedule),
                  const SizedBox(height: 8),
                  Text(
                    car == null
                        ? 'Авто удалено'
                        : '${car.make} ${car.model} (${car.plateDisplay})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pill(
                        text: 'Стоимость: $total ₽',
                        icon: Icons.payments_outlined,
                      ),
                      _pill(
                        text: 'К оплате: $toPay ₽',
                        icon: Icons.credit_card,
                      ),
                      if (addonsCount > 0)
                        _pill(
                          text: 'Доп. услуги: +$addonsCount',
                          icon: Icons.add_circle_outline,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _bayRow(b.bayId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waitlistCard({
    required Map<String, dynamic> w,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    final dt = _waitlistDateTime(w);
    final bayId = _waitlistDesiredBay(w);
    final reason = _waitlistReason(w);
    final carLine = _waitlistCarLine(w);
    final serviceName = _waitlistServiceName(w);

    final badge = _statusBadgeText('ОЖИДАНИЕ', Colors.orange);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: _sectionBox(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _waitlistThumb(w),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface.withValues(alpha: 0.92),
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 10),
                  _pill(text: _dtInline(dt), icon: Icons.schedule),
                  const SizedBox(height: 8),
                  if (carLine.trim().isNotEmpty)
                    Text(
                      carLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _pill(
                    text: reason,
                    icon: Icons.hourglass_bottom,
                    borderTint: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _bayRow(bayId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BookingsBundle>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _refresh,
                child: const Text('Повторить'),
              ),
            ),
          );
        }

        final data = snap.data!;
        final carsById = {for (final c in data.cars) c.id: c};
        final servicesById = {for (final s in data.services) s.id: s};

        // ✅ unified items
        final items = <_UnifiedItem>[
          for (final b in data.bookings) _UnifiedItem.booking(b),
          for (final w in data.waitlist) _UnifiedItem.waitlist(w),
        ];

        // sort desc by datetime
        items.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(
              icon: Icons.event_busy,
              title: 'Нет записей',
              subtitle: 'Создай запись — она появится здесь',
            ),
          );
        }

        final listChildren = <Widget>[const SizedBox(height: 12)];

        String? lastDay;
        for (final it in items) {
          final day = _dateKey(it.dateTime);
          if (day != lastDay) {
            lastDay = day;
            listChildren.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Text(
                  _dateHeader(it.dateTime),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.92),
                  ),
                ),
              ),
            );
          }

          listChildren.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: it.isBooking
                  ? _bookingCard(
                      b: it.booking!,
                      car: carsById[it.booking!.carId],
                      service: servicesById[it.booking!.serviceId],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookingDetailsPage(
                              repo: widget.repo,
                              bookingId: it.booking!.id,
                            ),
                          ),
                        );
                        _refresh();
                      },
                    )
                  : _waitlistCard(
                      w: it.waitlist!,
                      onTap: () async {
                        // simplest & safe: open WaitlistPage (там уже есть отмена ожидания)
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WaitlistPage(repo: widget.repo),
                          ),
                        );
                        _refresh();
                      },
                    ),
            ),
          );
        }

        listChildren.add(const SizedBox(height: 16));
        return ListView(children: listChildren);
      },
    );
  }
}

class _BookingsBundle {
  final List<Booking> bookings;
  final List<Car> cars;
  final List<Service> services;
  final List<Map<String, dynamic>> waitlist;

  const _BookingsBundle({
    required this.bookings,
    required this.cars,
    required this.services,
    required this.waitlist,
  });
}

class _UnifiedItem {
  final Booking? booking;
  final Map<String, dynamic>? waitlist;
  final DateTime dateTime;
  final bool isBooking;

  _UnifiedItem._({
    required this.booking,
    required this.waitlist,
    required this.dateTime,
    required this.isBooking,
  });

  factory _UnifiedItem.booking(Booking b) {
    return _UnifiedItem._(
      booking: b,
      waitlist: null,
      dateTime: b.dateTime.toLocal(),
      isBooking: true,
    );
  }

  factory _UnifiedItem.waitlist(Map<String, dynamic> w) {
    final iso = (w['desiredDateTime'] ?? w['dateTime'] ?? '').toString().trim();
    final dt = DateTime.tryParse(iso)?.toLocal() ?? DateTime.now();
    return _UnifiedItem._(
      booking: null,
      waitlist: w,
      dateTime: dt,
      isBooking: false,
    );
  }
}
