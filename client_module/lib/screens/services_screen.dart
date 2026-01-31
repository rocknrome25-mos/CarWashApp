import 'package:flutter/material.dart';
import '../core/data/app_repository.dart';
import '../core/models/service.dart';
import '../widgets/empty_state.dart';
import 'service_details_page.dart';

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

  String _priceLine(Service s) {
    final dur = s.durationMin ?? 30;
    return '${s.priceRub} ₽  •  $dur мин';
  }

  ImageProvider _serviceThumb(Service s) {
    if (s.imageUrl != null && s.imageUrl!.isNotEmpty) {
      return NetworkImage(s.imageUrl!);
    }

    final n = s.name.toLowerCase();
    if (n.contains('воск')) {
      return const AssetImage('assets/images/services/vosk_1080.jpg');
    }
    if (n.contains('комплекс')) {
      return const AssetImage('assets/images/services/kompleks_1080.jpg');
    }
    return const AssetImage('assets/images/services/kuzov_1080.jpg');
  }

  Future<void> _openDetails(Service s) async {
    final nav = Navigator.of(context);

    final booked = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => ServiceDetailsPage(repo: widget.repo, service: s),
      ),
    );

    if (!mounted) return;

    if (booked == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Запись создана')));
      widget.onBookingCreated();
      _refreshSync(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                  Text(
                    'Ошибка: ${snapshot.error}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
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
            subtitle: 'Backend вернул пустой список услуг.',
          );
        }

        final primary = cs.primary;

        return RefreshIndicator(
          onRefresh: _pullToRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // top hint card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.local_car_wash, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выбери услугу и время',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface.withValues(alpha: 0.95),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Сначала открой услугу, затем нажми “Записаться”.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.70),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Услуги',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 10),

              // cards
              for (final s in services)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openDetails(s),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        height: 96, // ✅ фикс, чтобы не было overflow
                        child: Row(
                          children: [
                            SizedBox(
                              width: 118,
                              height: 96,
                              child: Image(
                                image: _serviceThumb(s),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: cs.surfaceContainerHighest.withValues(
                                    alpha: 0.22,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_car_wash,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: cs.onSurface.withValues(
                                              alpha: 0.95,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _priceLine(s),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: cs.onSurface.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Посмотреть →',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: primary.withValues(
                                              alpha: 0.92,
                                            ),
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
