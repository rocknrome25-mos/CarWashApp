import 'package:flutter/material.dart';
import '../../core/models/service.dart';

class ServiceDetailsPage extends StatelessWidget {
  final Service service;
  final VoidCallback onBook;

  const ServiceDetailsPage({
    super.key,
    required this.service,
    required this.onBook,
  });

  ImageProvider _hero(Service s) {
    if (s.imageUrl != null && s.imageUrl!.isNotEmpty) {
      return NetworkImage(s.imageUrl!);
    }

    final n = s.name.toLowerCase();
    if (n.contains('воск')) {
      return const AssetImage('assets/images/services/vosk_hero.jpg');
    }
    if (n.contains('комплекс')) {
      return const AssetImage('assets/images/services/kompleks_hero.jpg');
    }
    if (n.contains('кузов')) {
      return const AssetImage('assets/images/services/kuzov_hero.jpg');
    }

    return const AssetImage('assets/images/services/default_hero.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final dur = service.durationMin ?? 30;

    final desc = service.description ??
        'Описание пока не задано. Можно добавить кратко: что входит, что будет сделано, для какого результата.';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image(
                  image: _hero(service),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              service.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.75),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _infoRow(title: 'Продолжительность', value: '$dur мин'),
            const SizedBox(height: 8),
            _infoRow(title: 'Стоимость', value: '${service.priceRub} ₽'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: onBook,
                child: const Text('Записаться'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.04),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black.withValues(alpha: 0.70),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
