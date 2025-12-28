import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';
import '../../widgets/empty_state.dart';
import 'add_car_sheet.dart';

class CarsPage extends StatefulWidget {
  final DemoRepository repo;

  const CarsPage({super.key, required this.repo});

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
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
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Авто добавлено')));
    }
  }

  Future<void> _confirmDeleteCar(String carId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить авто?'),
        content: const Text(
          'Также будут удалены все записи, связанные с этим авто.',
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

    widget.repo.deleteCar(carId);
    if (!mounted) return;

    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Авто удалено')));
  }

  @override
  Widget build(BuildContext context) {
    final cars = widget.repo.getCars();

    return Scaffold(
      body: cars.isEmpty
          ? const EmptyState(
              icon: Icons.directions_car,
              title: 'Нет авто',
              subtitle:
                  'Добавь машину, чтобы можно было записываться на услуги.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cars.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = cars[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_car),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addCar,
        child: const Icon(Icons.add),
      ),
    );
  }
}
