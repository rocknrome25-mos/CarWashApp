import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';

class CarsPage extends StatelessWidget {
  final DemoRepository repo;
  const CarsPage({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final cars = repo.getCars();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Авто',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (cars.isEmpty) const Text('Пока нет авто.'),
        ...cars.map(
          (c) => ListTile(
            title: Text('${c.make} ${c.model}'),
            subtitle: Text(c.plate),
          ),
        ),
      ],
    );
  }
}
