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
    return const AssetImage('assets/images/services/kuzov_1080.jpg');
  }

  Future<Object?> _bookNow(BuildContext context) async {
    final nav = Navigator.of(context);

    final created = await nav.push<Object?>(
      MaterialPageRoute(
        builder: (_) =>
            CreateBookingPage(repo: repo, preselectedServiceId: service.id),
      ),
    );

    if (!context.mounted) return null;
    return created;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.22,
                        ),
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
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.70,
                          ),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: Icon(Icons.arrow_back, color: cs.onSurface),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _priceLine(service),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.75),
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
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Описание',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Описание услуги будет здесь. Что входит, ограничения, рекомендации.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.75),
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
                  final res = await _bookNow(context);
                  if (!context.mounted) return;

                  if (res == true || res == 'waitlisted') {
                    Navigator.of(context).pop(res);
                  }
                },
                child: Text(
                  'Записаться',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
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
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
