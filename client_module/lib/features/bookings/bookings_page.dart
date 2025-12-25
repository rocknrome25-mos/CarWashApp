import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';

class BookingsPage extends StatelessWidget {
  final DemoRepository repo;
  const BookingsPage({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final bookings = repo.getBookings();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Записи',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (bookings.isEmpty) const Text('Пока нет записей.'),
        ...bookings.map(
          (b) => ListTile(
            title: Text('${b.car.make} ${b.car.model} • ${b.service.name}'),
            subtitle: Text(b.startAt.toString()),
          ),
        ),
      ],
    );
  }
}
