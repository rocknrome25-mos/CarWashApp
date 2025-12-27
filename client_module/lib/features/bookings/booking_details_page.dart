import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final details = repo.getBookingDetails(bookingId);

    if (details == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Детали записи')),
        body: const Center(child: Text('Запись не найдена')),
      );
    }

    final b = details.booking;
    final car = details.car;
    final service = details.service;

    final dateStr = DateFormat('dd.MM.yyyy').format(b.dateTime);
    final timeStr = DateFormat('HH:mm').format(b.dateTime);

    return Scaffold(
      appBar: AppBar(title: const Text('Детали записи')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Row(label: 'Дата', value: dateStr),
            const SizedBox(height: 10),
            _Row(label: 'Время', value: timeStr),
            const Divider(height: 28),
            _Row(
              label: 'Авто',
              value: car == null
                  ? 'Удалено'
                  : '${car.brand} ${car.model} (${car.plate})',
            ),
            const SizedBox(height: 10),
            _Row(
              label: 'Услуга',
              value: service == null ? 'Удалено' : service.name,
            ),
            if (service != null) ...[
              const SizedBox(height: 10),
              _Row(label: 'Цена', value: '${service.priceRub} ₽'),
              const SizedBox(height: 10),
              _Row(label: 'Длительность', value: '${service.durationMin} мин'),
            ],
            const Spacer(),
            FilledButton.icon(
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

                if (ok == true && context.mounted) {
                  repo.deleteBooking(b.id);
                  Navigator.of(context).pop(true);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить запись'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: theme.textTheme.titleMedium)),
      ],
    );
  }
}
