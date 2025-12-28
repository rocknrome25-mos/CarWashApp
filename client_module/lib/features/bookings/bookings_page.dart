import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';
import '../../widgets/empty_state.dart';
import 'booking_details_page.dart';

class BookingsPage extends StatefulWidget {
  final DemoRepository repo;

  const BookingsPage({super.key, required this.repo});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  @override
  Widget build(BuildContext context) {
    final bookings = widget.repo.getBookings();

    if (bookings.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'Пока нет записей',
        subtitle: 'Создай запись на услугу — она появится здесь.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final b = bookings[i];
        final car = widget.repo.findCar(b.carId);
        final service = widget.repo.findService(b.serviceId);

        final carTitle = car == null
            ? 'Авто удалено'
            : '${car.make} ${car.model} (${car.plateDisplay})';
        final serviceTitle = service?.name ?? 'Услуга удалена';

        final dt = b.dateTime;
        final dtText =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        return Card(
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(serviceTitle),
            subtitle: Text('$carTitle\n$dtText'),
            isThreeLine: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      BookingDetailsPage(repo: widget.repo, bookingId: b.id),
                ),
              );
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Удалить запись?'),
                    content: const Text(
                      'Запись будет удалена без возможности восстановления.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Удалить'),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                widget.repo.deleteBooking(b.id);
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Запись удалена')));
              },
            ),
          ),
        );
      },
    );
  }
}
