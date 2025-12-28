import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';
import '../../widgets/empty_state.dart';
import '../bookings/create_booking_page.dart';

class ServicesPage extends StatelessWidget {
  final DemoRepository repo;

  const ServicesPage({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final cars = repo.getCars();
    final services = repo.getServices();

    if (cars.isEmpty) {
      return const EmptyState(
        icon: Icons.info_outline,
        title: 'Сначала добавь авто',
        subtitle:
            'Чтобы записаться на услугу, нужно добавить хотя бы одну машину.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ...services.map((s) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.local_car_wash),
              title: Text(s.name),
              subtitle: Text('${s.priceRub} ₽ • ${s.durationMin} мин'),
              trailing: FilledButton(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => CreateBookingPage(
                        repo: repo,
                        preselectedServiceId: s.id,
                      ),
                    ),
                  );
                  if (created == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Запись создана')),
                    );
                  }
                },
                child: const Text('Записаться'),
              ),
            ),
          );
        }),
      ],
    );
  }
}
