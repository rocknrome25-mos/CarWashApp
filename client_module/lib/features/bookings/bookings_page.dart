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
  // ✅ цвета линий/постов — оставляем (идентификация)
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
      _refreshSync(force: true);
    }
  }

  Future<_BookingsBundle> _load({bool forceRefresh = false}) async {
    final results = await Future.wait([
      widget.repo.getBookings(
        includeCanceled: true,
        forceRefresh: forceRefresh,
      ),
      widget.repo.getCars(forceRefresh: forceRefresh),
      widget.repo.getServices(forceRefresh: forceRefresh),
    ]);

    return _BookingsBundle(
      bookings: results[0] as List<Booking>,
      cars: results[1] as List<Car>,
      services: results[2] as List<Service>,
    );
  }

  void _refreshSync({bool force = true}) {
    setState(() {
      _future = _load(forceRefresh: force);
    });
  }

  Future<void> _pullToRefresh() async {
    _refreshSync(force: true);
    try {
      await _future;
    } catch (_) {}
  }

  DateTime _local(DateTime dt) => dt.toLocal();

  String _dateKey(DateTime dt) {
    final x = _local(dt);
    return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  String _dateHeader(DateTime dt) {
    final x = _local(dt);
    return '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  }

  String _dateText(DateTime dt) {
    final x = _local(dt);
    return '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';
  }

  String _timeText(DateTime dt) {
    final x = _local(dt);
    return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  String _dateTimeText(DateTime dt) {
    final x = _local(dt);
    return '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year} '
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  String _statusText(Booking b) {
    switch (b.status) {
      case BookingStatus.active:
        return 'Забронировано';
      case BookingStatus.pendingPayment:
        return 'Ожидает оплаты';
      case BookingStatus.completed:
        return 'Завершено';
      case BookingStatus.canceled:
        return 'Отменено';
    }
  }

  // ✅ статусы: active = primary, остальное — аккуратно цветом
  Color _statusColor(BuildContext context, Booking b) {
    final cs = Theme.of(context).colorScheme;
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

  Widget _statusBadgeForTabs({required Booking b, required bool isActiveTab}) {
    if (isActiveTab) {
      if (b.status == BookingStatus.pendingPayment) {
        return _badge(text: 'ОЖИДАЕТ ОПЛАТЫ', color: _statusColor(context, b));
      }
      if (b.status == BookingStatus.active) {
        return _badge(text: 'ЗАБРОНИРОВАНО', color: _statusColor(context, b));
      }
      return const SizedBox.shrink();
    }

    return _badge(
      text: _statusText(b).toUpperCase(),
      color: _statusColor(context, b),
    );
  }

  int _compareBookings(Booking a, Booking b) => b.dateTime.compareTo(a.dateTime);

  Color _lineColor(BuildContext context, int? bayId) {
    if (bayId == 1) return _greenLine;
    if (bayId == 2) return _blueLine;
    return Theme.of(context).colorScheme.outlineVariant; // любая/не задано
  }

  String _lineText(int? bayId) {
    if (bayId == 1) return 'Зелёная линия';
    if (bayId == 2) return 'Синяя линия';
    return 'Любая линия';
  }

  // ✅ сервис-картинка (по твоей структуре ассетов)
  String _serviceImageAsset(Service? s) {
    final name = (s?.name ?? '').toLowerCase();
    if (name.contains('комплекс')) return 'assets/images/services/kompleks_512.jpg';
    if (name.contains('кузов')) return 'assets/images/services/kuzov_512.jpg';
    if (name.contains('воск')) return 'assets/images/services/vosk_512.jpg';

    // fallback (не падаем)
    return 'assets/images/services/kuzov_512.jpg';
  }

  Widget _serviceThumb(Service? service) {
    final path = _serviceImageAsset(service);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        path,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_car_wash),
          );
        },
      ),
    );
  }

  // ✅ (опционально) иконки постов — поменяешь пути под свои ассеты
  String _bayIconAsset(int? bayId) {
    if (bayId == 1) return 'assets/images/posts/post_green.png';
    if (bayId == 2) return 'assets/images/posts/post_blue.png';
    return 'assets/images/posts/post_any.png';
  }

  Widget _bayIndicator(int? bayId) {
    final color = _lineColor(context, bayId);
    return Image.asset(
      _bayIconAsset(bayId),
      width: 16,
      height: 16,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      },
    );
  }

  Widget _bookingCard({
    required Booking b,
    required Car? car,
    required Service? service,
    required bool isActiveTab,
    required VoidCallback onTap,
  }) {
    final serviceTitle = service?.name ?? 'Услуга удалена';
    final carTitle = car == null
        ? 'Авто удалено'
        : '${car.make} ${car.model} (${car.plateDisplay})';
    final when = '${_dateText(b.dateTime)} • ${_timeText(b.dateTime)}';

    final total = service?.priceRub;
    final paid = b.paidTotalRub;
    final paidLine = (total == null) ? null : 'Оплачено: $paid ₽ из $total ₽';

    String? paymentLine;
    if (b.status == BookingStatus.pendingPayment && b.paymentDueAt != null) {
      paymentLine = 'Оплатить до: ${_timeText(b.paymentDueAt!)}';
    } else if (b.lastPaidAt != null) {
      paymentLine = 'Платёж: ${_dateTimeText(b.lastPaidAt!)}';
    }

    final badge = _statusBadgeForTabs(b: b, isActiveTab: isActiveTab);
    final int? bayId = b.bayId;

    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          serviceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    carTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  // ✅ линия (без "Линия:")
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _bayIndicator(bayId),
                      const SizedBox(width: 8),
                      Text(
                        _lineText(bayId),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  if (paymentLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      paymentLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (paidLine != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      paidLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList({
    required List<Booking> bookings,
    required Map<String, Car> carsById,
    required Map<String, Service> servicesById,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isActiveTab,
  }) {
    if (bookings.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    final rows = <_Row>[];
    String? currentDay;

    for (final b in bookings) {
      final day = _dateKey(b.dateTime);
      if (day != currentDay) {
        currentDay = day;
        rows.add(_Row.header(_dateHeader(b.dateTime)));
      }
      rows.add(_Row.booking(b));
    }

    return RefreshIndicator(
      onRefresh: _pullToRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];

          if (row.kind == _RowKind.header) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
              child: Text(
                row.headerText!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          }

          final b = row.booking!;
          final car = carsById[b.carId];
          final service = servicesById[b.serviceId];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _bookingCard(
              b: b,
              car: car,
              service: service,
              isActiveTab: isActiveTab,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailsPage(repo: widget.repo, bookingId: b.id),
                  ),
                );
                if (!mounted) return;
                _refreshSync(force: true);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BookingsBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ошибка: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _refreshSync(force: true),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final all = [...data.bookings];

        final carsById = {for (final c in data.cars) c.id: c};
        final servicesById = {for (final s in data.services) s.id: s};

        final active = all
            .where(
              (b) =>
                  b.status == BookingStatus.active ||
                  b.status == BookingStatus.pendingPayment,
            )
            .toList();

        final completed = all
            .where((b) => b.status == BookingStatus.completed)
            .toList();

        final canceled = all
            .where((b) => b.status == BookingStatus.canceled)
            .toList();

        active.sort(_compareBookings);
        completed.sort(_compareBookings);
        canceled.sort(_compareBookings);

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const Material(
                child: TabBar(
                  tabs: [
                    Tab(text: 'Активные'),
                    Tab(text: 'Завершённые'),
                    Tab(text: 'Отменённые'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList(
                      bookings: active,
                      carsById: carsById,
                      servicesById: servicesById,
                      emptyTitle: 'Нет активных записей',
                      emptySubtitle:
                          'Создай запись на услугу — она появится здесь.',
                      isActiveTab: true,
                    ),
                    _buildList(
                      bookings: completed,
                      carsById: carsById,
                      servicesById: servicesById,
                      emptyTitle: 'Нет завершённых записей',
                      emptySubtitle: 'Здесь будут прошедшие записи.',
                      isActiveTab: false,
                    ),
                    _buildList(
                      bookings: canceled,
                      carsById: carsById,
                      servicesById: servicesById,
                      emptyTitle: 'Нет отменённых записей',
                      emptySubtitle: 'Здесь будут отменённые записи.',
                      isActiveTab: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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

enum _RowKind { header, booking }

class _Row {
  final _RowKind kind;
  final String? headerText;
  final Booking? booking;

  _Row.header(this.headerText) : kind = _RowKind.header, booking = null;
  _Row.booking(this.booking) : kind = _RowKind.booking, headerText = null;
}
