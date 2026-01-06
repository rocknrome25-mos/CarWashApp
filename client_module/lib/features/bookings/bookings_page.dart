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

  String _timeText(DateTime dt) {
    final x = _local(dt);
    return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  String _dateTimeText(DateTime dt) {
    final x = _local(dt);
    return '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year} '
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusChip(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingPayment:
        return const Chip(label: Text('ОЖИДАЕТ ОПЛАТЫ'), side: BorderSide.none);
      case BookingStatus.canceled:
        return const Chip(label: Text('ОТМЕНЕНА'), side: BorderSide.none);
      case BookingStatus.completed:
        return const Chip(label: Text('ЗАВЕРШЕНА'), side: BorderSide.none);
      case BookingStatus.active:
        return const Chip(label: Text('АКТИВНА'), side: BorderSide.none);
    }
  }

  Widget _paidChip() {
    return const Chip(label: Text('ОПЛАЧЕНО'), side: BorderSide.none);
  }

  int _compareBookings(
    Booking a,
    Booking b,
    String carTitleA,
    String carTitleB,
  ) {
    final byTime = b.dateTime.compareTo(a.dateTime); // newest first
    if (byTime != 0) return byTime;
    return carTitleA.toLowerCase().compareTo(carTitleB.toLowerCase());
  }

  Widget _buildList({
    required List<Booking> bookings,
    required Map<String, Car> carsById,
    required Map<String, Service> servicesById,
    required String emptyTitle,
    required String emptySubtitle,
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
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];

          if (row.kind == _RowKind.header) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                row.headerText!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final b = row.booking!;
          final car = carsById[b.carId];
          final service = servicesById[b.serviceId];

          final carTitle = car == null
              ? 'Авто удалено'
              : '${car.make} ${car.model} (${car.plateDisplay})';
          final serviceTitle = service?.name ?? 'Услуга удалена';
          final timeText = _timeText(b.dateTime);

          // payment line
          String? paymentLine;
          if (b.status == BookingStatus.pendingPayment &&
              b.paymentDueAt != null) {
            paymentLine = 'Оплатить до: ${_timeText(b.paymentDueAt!)}';
          } else if (b.status == BookingStatus.active && b.paidAt == null) {
            // активна, но paidAt нет — теоретически не должно быть, но лучше подсветить
            paymentLine = 'Оплата: не подтверждена';
          } else if (b.paidAt != null) {
            paymentLine = 'Оплата: ${_dateTimeText(b.paidAt!)}';
          }

          final subtitle = paymentLine == null
              ? '$carTitle\n$timeText'
              : '$carTitle\n$timeText • $paymentLine';

          // trailing chips: статус + (оплачено)
          final trailing = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusChip(b.status),
              if (b.paidAt != null) ...[const SizedBox(height: 6), _paidChip()],
            ],
          );

          return Card(
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(serviceTitle),
              subtitle: Text(subtitle),
              isThreeLine: true,
              trailing: trailing,
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

        // active bucket includes pendingPayment
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

        void sortBucket(List<Booking> list) {
          list.sort((a, b) {
            final carA = carsById[a.carId];
            final carB = carsById[b.carId];
            final carTitleA = carA == null
                ? 'Авто удалено'
                : '${carA.make} ${carA.model} (${carA.plateDisplay})';
            final carTitleB = carB == null
                ? 'Авто удалено'
                : '${carB.make} ${carB.model} (${carB.plateDisplay})';
            return _compareBookings(a, b, carTitleA, carTitleB);
          });
        }

        sortBucket(active);
        sortBucket(completed);
        sortBucket(canceled);

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
                    ),
                    _buildList(
                      bookings: completed,
                      carsById: carsById,
                      servicesById: servicesById,
                      emptyTitle: 'Нет завершённых записей',
                      emptySubtitle: 'Здесь будут прошедшие записи.',
                    ),
                    _buildList(
                      bookings: canceled,
                      carsById: carsById,
                      servicesById: servicesById,
                      emptyTitle: 'Нет отменённых записей',
                      emptySubtitle: 'Здесь будут отменённые записи.',
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
