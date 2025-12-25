import 'package:flutter/material.dart';
import '../../core/data/demo_repository.dart';

class ServicesPage extends StatelessWidget {
  final DemoRepository repo;
  const ServicesPage({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final services = repo.getServices();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Услуги',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...services.map(
          (s) => ListTile(
            title: Text(s.name),
            subtitle: Text('${s.durationMinutes} мин'),
            trailing: Text('${s.price} ₽'),
          ),
        ),
      ],
    );
  }
}
