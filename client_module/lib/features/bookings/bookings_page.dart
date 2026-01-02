import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import '../../widgets/empty_state.dart';
import 'booking_details_page.dart';

class BookingsPage extends StatefulWidget {
  final AppRepository repo;

  const BookingsPage({super.key, required this.repo});

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

  void _refresh() {
    setState(() => _future = _load(forceRefresh: true));
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
        final bookings = data.bookings;

        if (bookings.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy,
            title: 'Пока нет записей',
            subtitle: 'Создай запись на услугу — она появится здесь.',
          );
        }

        final carsById = {for (final c in data.cars) c.id: c};
        final servicesById = {for (final s in data.services) s.id: s};

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, i) {
              final b = bookings[i];
              final car = carsById[b.carId];
              final service = servicesById[b.serviceId];

              final carTitle = car == null
                  ? 'Авто удалено'
                  : '${car.make} ${car.model} (${car.plateDisplay})';
              final serviceTitle = service?.name ?? 'Услуга удалена';

              final dt = b.dateTime;
              final dtText =
                  '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              final statusText = (b.status == BookingStatus.canceled)
                  ? 'ОТМЕНЕНА'
                  : 'АКТИВНА';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(serviceTitle),
                  subtitle: Text('$carTitle\n$dtText\n$statusText'),
                  isThreeLine: true,
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
