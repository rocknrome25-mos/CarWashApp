import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';
import '../core/models/service.dart';
import '../widgets/empty_state.dart';
import '../features/bookings/create_booking_page.dart';

class ServicesScreen extends StatefulWidget {
  final AppRepository repo;
  final int refreshToken;
  final VoidCallback onBookingCreated;

  const ServicesScreen({
    super.key,
    required this.repo,
    required this.refreshToken,
    required this.onBookingCreated,
  });

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late Future<_ServicesBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refreshSync(force: true);
    }
  }

  Future<_ServicesBundle> _load({bool forceRefresh = false}) async {
    final results = await Future.wait([
      widget.repo.getCars(forceRefresh: forceRefresh),
      widget.repo.getServices(forceRefresh: forceRefresh),
    ]);

    return _ServicesBundle(
      carsCount: (results[0] as List).length,
      services: results[1] as List<Service>,
    );
  }

  void _refreshSync({bool force = true}) {
    setState(() {
      _future = _load(forceRefresh: force);
    });
  }

  Future<void> _pullToRefresh() async {
    _refreshSync(force: true);
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ServicesBundle>(
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
                    onPressed: () => _refreshSync(force: true),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        if (data.carsCount == 0) {
          return const EmptyState(
            icon: Icons.info_outline,
            title: 'Сначала добавь авто',
            subtitle:
                'Чтобы записаться на услугу, нужно добавить хотя бы одну машину.',
          );
        }

        final services = data.services;
        if (services.isEmpty) {
          return const EmptyState(
            icon: Icons.local_car_wash,
            title: 'Нет услуг',
            subtitle: 'Похоже, backend вернул пустой список услуг.',
          );
        }

        return RefreshIndicator(
          onRefresh: _pullToRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: services.length,
            itemBuilder: (context, i) {
              final s = services[i];
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

                        widget.onBookingCreated(); // обновить вкладку "Записи"
                        _refreshSync(force: true); // и услуги/машины освежить
                      }
                    },
                    child: const Text('Записаться'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ServicesBundle {
  final int carsCount;
  final List<Service> services;

  const _ServicesBundle({required this.carsCount, required this.services});
}
