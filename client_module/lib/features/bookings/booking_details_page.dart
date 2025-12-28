import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';

class BookingDetailsPage extends StatelessWidget {
  final DemoRepository repo;
  final String bookingId;

  const BookingDetailsPage({
    super.key,
    required this.repo,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    final booking = repo
        .getBookings()
        .where((b) => b.id == bookingId)
        .cast()
        .toList()
        .firstOrNull;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Детали записи')),
        body: const Center(child: Text('Запись не найдена')),
      );
    }

    final car = repo.findCar(booking.carId);
    final service = repo.findService(booking.serviceId);

    final dt = booking.dateTime;
    final dtText =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Детали записи')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service?.name ?? 'Услуга удалена',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(dtText),
            const SizedBox(height: 16),
            const Text('Авто', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(car == null ? 'Авто удалено' : '${car.make} ${car.model}'),
            if (car != null) Text(car.subtitle),
            const SizedBox(height: 16),
            const Text(
              'Стоимость',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(service == null ? '—' : '${service.priceRub} ₽'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Назад'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
