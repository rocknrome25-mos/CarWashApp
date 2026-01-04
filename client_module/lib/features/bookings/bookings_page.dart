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
      _refresh();
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

  void _refresh() => setState(() => _future = _load(forceRefresh: true));

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _dateHeader(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  String _timeText(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _statusChip(BookingStatus status) {
    final isCanceled = status == BookingStatus.canceled;
    return Chip(
      label: Text(isCanceled ? 'ОТМЕНЕНА' : 'АКТИВНА'),
      side: BorderSide.none,
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
                    onPressed: _refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final bookings = [...data.bookings];

        if (bookings.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy,
            title: 'Пока нет записей',
            subtitle: 'Создай запись на услугу — она появится здесь.',
          );
        }

        // sort newest first
        bookings.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        final carsById = {for (final c in data.cars) c.id: c};
        final servicesById = {for (final s in data.services) s.id: s};

        // build grouped rows
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
          onRefresh: () async => _refresh(),
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

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(serviceTitle),
                  subtitle: Text('$carTitle\n$timeText'),
                  isThreeLine: true,
                  trailing: _statusChip(b.status),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingDetailsPage(
                          repo: widget.repo,
                          bookingId: b.id,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    _refresh();
                  },
                ),
              );
            },
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
