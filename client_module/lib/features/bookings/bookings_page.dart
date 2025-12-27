import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        icon: Icons.event_available,
        title: 'Нет записей',
        subtitle: 'Создай запись через вкладку “Услуги”.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final b = bookings[i];
        final car = widget.repo.findCar(b.carId);
        final service = widget.repo.findService(b.serviceId);

        final dateStr = DateFormat('dd.MM.yyyy').format(b.dateTime);
        final timeStr = DateFormat('HH:mm').format(b.dateTime);

        final title = service?.name ?? 'Услуга';
        final subtitle =
            '${car == null ? 'Авто удалено' : '${car.brand} ${car.model} (${car.plate})'} • $dateStr $timeStr';

        return Card(
          child: ListTile(
            leading: const Icon(Icons.event_note),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      BookingDetailsPage(repo: widget.repo, bookingId: b.id),
                ),
              );

              if (changed == true && mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Запись обновлена')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
