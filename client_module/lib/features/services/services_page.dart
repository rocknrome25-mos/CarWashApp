import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';
import '../../widgets/empty_state.dart';
import '../bookings/create_booking_page.dart';

class ServicesPage extends StatefulWidget {
  final DemoRepository repo;

  const ServicesPage({super.key, required this.repo});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  Future<void> _confirmDeleteService(String serviceId) async {
    if (widget.repo.isServiceProtected(serviceId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Эту услугу нельзя удалить (демо)')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить услугу?'),
        content: const Text(
          'Также будут удалены все записи, связанные с этой услугой.',
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

    final deleted = widget.repo.deleteService(serviceId);

    if (!mounted) return;
    if (deleted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Услуга удалена')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить услугу')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cars = widget.repo.getCars();
    final services = widget.repo.getServices();

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
              onLongPress: () => _confirmDeleteService(s.id),
              leading: const Icon(Icons.local_car_wash),
              title: Text(s.name),
              subtitle: Text('${s.priceRub} ₽ • ${s.durationMin} мин'),
              trailing: FilledButton(
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => CreateBookingPage(
                        repo: widget.repo,
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
