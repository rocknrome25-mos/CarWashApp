import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';
import '../../core/models/service.dart';
import '../../widgets/empty_state.dart';
import '../bookings/create_booking_page.dart';
import '../../api/services_api.dart';

class ServicesPage extends StatefulWidget {
  final DemoRepository repo;
  final VoidCallback onBookingCreated;

  const ServicesPage({
    super.key,
    required this.repo,
    required this.onBookingCreated,
  });

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late final ServicesApi api;
  late Future<List<Service>> future;

  @override
  void initState() {
    super.initState();
    api = ServicesApi(baseUrl: 'http://10.0.2.2:3000');
    future = api.fetchServices();
  }

  @override
  Widget build(BuildContext context) {
    final cars = widget.repo.getCars();

    if (cars.isEmpty) {
      return const EmptyState(
        icon: Icons.info_outline,
        title: 'Сначала добавь авто',
        subtitle:
            'Чтобы записаться на услугу, нужно добавить хотя бы одну машину.',
      );
    }

    return FutureBuilder<List<Service>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final services = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ...services.map((s) {
              final durationText = s.durationMin == null
                  ? ''
                  : ' • ${s.durationMin} мин';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_car_wash),
                  title: Text(s.name),
                  subtitle: Text('${s.priceRub} ₽$durationText'),
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

                      if (!context.mounted) return;

                      if (created == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Запись создана')),
                        );
                        widget.onBookingCreated();
                      }
                    },
                    child: const Text('Записаться'),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
