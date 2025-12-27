import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/demo_repository.dart';
import '../../widgets/empty_state.dart';

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
        subtitle: 'Выбери услугу и создай первую запись.',
      );
    }

    final fmt = DateFormat('dd.MM.yyyy HH:mm', 'ru');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        final car = widget.repo.findCar(b.carId);
        final service = widget.repo.findService(b.serviceId);

        final carText = car == null
            ? 'Авто удалено'
            : '${car.brand} ${car.model} (${car.plate})';
        final serviceText = service == null ? 'Услуга удалена' : service.name;

        return Card(
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(serviceText),
            subtitle: Text('$carText\n${fmt.format(b.dateTime)}'),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  widget.repo.deleteBooking(b.id);
                });
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
