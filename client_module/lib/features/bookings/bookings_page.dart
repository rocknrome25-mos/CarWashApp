import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import '../../widgets/empty_state.dart';
import 'booking_details_page.dart';

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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant BookingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
    }
  }

  Future<_BookingsBundle> _load({bool force = false}) async {
    final res = await Future.wait([
      widget.repo.getBookings(includeCanceled: true, forceRefresh: force),
      widget.repo.getCars(forceRefresh: force),
      widget.repo.getServices(forceRefresh: force),
    ]);

    return _BookingsBundle(
      bookings: res[0] as List<Booking>,
      cars: res[1] as List<Car>,
      services: res[2] as List<Service>,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load(force: true);
    });
  }

  // ================= helpers =================

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

  Color _statusColor(BuildContext ctx, BookingStatus s) {
    final cs = Theme.of(ctx).colorScheme;
    switch (s) {
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

  String _statusText(BookingStatus s) {
    switch (s) {
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
    if (name.contains('комплекс')) {
      return 'assets/images/services/kompleks_512.jpg';
    }
    if (name.contains('воск')) {
      return 'assets/images/services/vosk_512.jpg';
    }
    return 'assets/images/services/kuzov_512.jpg';
  }

  // ================= widgets =================

  Widget _statusBadge(BuildContext ctx, Booking b) {
    final c = _statusColor(ctx, b.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(b.status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: c,
        ),
      ),
    );
  }

  Widget _bayBadge(BuildContext ctx, int? bayId) {
    final color = _bayColor(ctx, bayId);

    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
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
        Text(
          _bayText(bayId),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _serviceThumb(Service? s) {
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
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.local_car_wash),
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
    final when = '${_dateHeader(b.dateTime)} • ${_time(b.dateTime)}';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(context, b),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    car == null
                        ? 'Авто удалено'
                        : '${car.make} ${car.model} (${car.plateDisplay})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _bayBadge(context, b.bayId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= build =================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BookingsBundle>(
      future: _future,
      builder: (ctx, snap) {
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

        if (bookings.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy,
            title: 'Нет записей',
            subtitle: 'Создай запись — она появится здесь',
          );
        }

        final rows = <Widget>[];
        String? lastDay;

        for (final b in bookings) {
          final day = _dateKey(b.dateTime);
          if (day != lastDay) {
            lastDay = day;
            rows.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  _dateHeader(b.dateTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }

          rows.add(
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

        return ListView(children: rows);
      },
    );
  }
}

// ================= models =================

class _BookingsBundle {
  final List<Booking> bookings;
  final List<Car> cars;
  final List<Service> services;

  const _BookingsBundle({
    required this.bookings,
    required this.cars,
    required this.services,
  });
}
