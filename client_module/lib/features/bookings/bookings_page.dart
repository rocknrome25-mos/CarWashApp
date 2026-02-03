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

  StreamSubscription? _rtSub;
  Timer? _rtDebounce;

  @override
  void initState() {
    super.initState();
    _future = _load(force: false);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _rtDebounce?.cancel();
    _rtSub?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    _rtSub?.cancel();
    _rtSub = widget.repo.bookingEvents.listen((_) {
      _rtDebounce?.cancel();
      _rtDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _refresh();
      });
    });
  }

  @override
  void didUpdateWidget(covariant BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
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

  Future<List<Map<String, dynamic>>> _loadWaitlist({required bool force}) async {
    final cid = widget.repo.currentClient?.id.trim() ?? '';
    if (cid.isEmpty) return const [];
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
    if (name.contains('комплекс')) return 'assets/images/services/kompleks_512.jpg';
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

  /// слой 2: секция (чуть светлее фона)
  Widget _sectionBox({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.10), // базовый слой секции
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }

  /// слой 3: элемент внутри секции (ещё светлее)
  Widget _pill({
    required String text,
    IconData? icon,
    Color? borderTint,
  }) {
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

  Widget _statusBadge(Booking b) {
    final c = _statusColor(context, b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(b),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c),
      ),
    );
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

  // ---------------- card ----------------

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
                  // header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service?.name ?? 'Услуга удалена',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(b),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // date/time as a clear pill (layer 3)
                  _pill(
                    text: _dtInline(b.dateTime),
                    icon: Icons.schedule,
                  ),

                  const SizedBox(height: 8),

                  // car (single line)
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

                  // money pills (layer 3)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pill(text: 'Стоимость: $total ₽', icon: Icons.payments_outlined),
                      _pill(text: 'К оплате: $toPay ₽', icon: Icons.credit_card),
                      if (addonsCount > 0)
                        _pill(text: 'Доп. услуги: +$addonsCount', icon: Icons.add_circle_outline),
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

  Widget _waitlistTopCard(int count) {
    final cs = Theme.of(context).colorScheme;

    return _sectionBox(
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ожидание: $count',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.95),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WaitlistPage(repo: widget.repo)),
              );
            },
            child: const Text('Показать'),
          ),
        ],
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

        final bookings = [...data.bookings]
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

        final listChildren = <Widget>[
          const SizedBox(height: 12),
          if (data.waitlist.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _waitlistTopCard(data.waitlist.length),
            ),
          ],
        ];

        if (bookings.isEmpty) {
          listChildren.add(
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.event_busy,
                title: 'Нет записей',
                subtitle: 'Создай запись — она появится здесь',
              ),
            ),
          );
          return ListView(children: listChildren);
        }

        String? lastDay;
        for (final b in bookings) {
          final day = _dateKey(b.dateTime);
          if (day != lastDay) {
            lastDay = day;
            listChildren.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Text(
                  _dateHeader(b.dateTime),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.92),
                  ),
                ),
              ),
            );
          }

          listChildren.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _bookingCard(
                b: b,
                car: carsById[b.carId],
                service: servicesById[b.serviceId],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingDetailsPage(
                        repo: widget.repo,
                        bookingId: b.id,
                      ),
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
