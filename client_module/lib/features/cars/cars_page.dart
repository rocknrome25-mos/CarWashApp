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
  void _openAddCar() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddCarSheet(repo: widget.repo),
    );
    if (added == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cars = widget.repo.getCars();

    if (cars.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car,
        title: 'Нет авто',
        subtitle: 'Добавь машину, чтобы записаться на мойку.',
        action: FilledButton(
          onPressed: _openAddCar,
          child: const Text('Добавить авто'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          onPressed: _openAddCar,
          icon: const Icon(Icons.add),
          label: const Text('Добавить авто'),
        ),
        const SizedBox(height: 12),
        ...cars.map((c) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(c.title),
              subtitle: Text('Номер: ${c.plate}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  widget.repo.deleteCar(c.id);
                  setState(() {});
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
