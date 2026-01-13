import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/car.dart';
import '../../widgets/empty_state.dart';
import 'add_car_sheet.dart';

class CarsPage extends StatefulWidget {
  final AppRepository repo;

  const CarsPage({super.key, required this.repo});

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  late Future<List<Car>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getCars();
  }

  void _refresh({bool force = false}) {
    setState(() {
      _future = widget.repo.getCars(forceRefresh: force);
    });
  }

  Future<void> _addCar() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddCarSheet(repo: widget.repo),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      _refresh(force: true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Авто добавлено')));
    }
  }

  Future<void> _confirmDeleteCar(String carId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить авто?'),
        content: const Text('Также будут удалены все записи, связанные с этим авто.'),
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

    if (!mounted) return;
    if (ok != true) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.repo.deleteCar(carId);
      if (!mounted) return;
      _refresh(force: true);
      messenger.showSnackBar(const SnackBar(content: Text('Авто удалено')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Car>>(
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
                      onPressed: () => _refresh(force: true),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final cars = snapshot.data ?? const <Car>[];

          if (cars.isEmpty) {
            return const EmptyState(
              icon: Icons.directions_car,
              title: 'Нет авто',
              subtitle: 'Добавь машину, чтобы можно было записываться на услуги.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(force: true),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cars.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = cars[i];
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        c.avatarAsset,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(c.title),
                    subtitle: Text(c.subtitle),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDeleteCar(c.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCar,
        child: const Icon(Icons.add),
      ),
    );
  }
}
