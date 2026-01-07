import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';
import '../core/models/service.dart';
import '../features/bookings/create_booking_page.dart';

class ServiceDetailsPage extends StatelessWidget {
  final AppRepository repo;
  final Service service;

  const ServiceDetailsPage({
    super.key,
    required this.repo,
    required this.service,
  });

  String _priceLine(Service s) {
    final dur = s.durationMin ?? 30;
    return '${s.priceRub} ₽  •  $dur мин';
  }

  ImageProvider _heroImageProvider() {
    final url = service.imageUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }

    final n = service.name.toLowerCase();
    if (n.contains('воск')) {
      return const AssetImage('assets/images/services/vosk_1080.jpg');
    }
    if (n.contains('комплекс')) {
      return const AssetImage('assets/images/services/kompleks_1080.jpg');
    }
    if (n.contains('кузов')) {
      return const AssetImage('assets/images/services/kuzov_1080.jpg');
    }

    // fallback на существующий файл
    return const AssetImage('assets/images/services/kuzov_1080.jpg');
  }

  Future<bool> _bookNow(BuildContext context) async {
    final nav = Navigator.of(context);

    final created = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CreateBookingPage(repo: repo, preselectedServiceId: service.id),
      ),
    );

    if (!context.mounted) return false;
    return created == true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final heroH = MediaQuery.of(context).size.width * 0.72;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(bottom: 92 + bottomInset),
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(26),
                      bottomRight: Radius.circular(26),
                    ),
                    child: Image(
                      image: _heroImageProvider(),
                      height: heroH,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: heroH,
                        width: double.infinity,
                        color: Colors.black.withValues(alpha: 0.06),
                        child: const Center(
                          child: Icon(Icons.local_car_wash, size: 54),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.88),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _priceLine(service),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Описание',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Описание услуги будет здесь. Что входит, ограничения, рекомендации.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _InfoChip(
                            label: 'Длительность',
                            value: '${service.durationMin ?? 30} мин',
                          ),
                          const SizedBox(width: 10),
                          _InfoChip(
                            label: 'Стоимость',
                            value: '${service.priceRub} ₽',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12 + bottomInset,
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  final ok = await _bookNow(context);
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text(
                  'Записаться',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
