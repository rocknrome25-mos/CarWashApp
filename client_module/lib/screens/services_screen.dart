// C:\dev\carwash\client_module\lib\screens\services_screen.dart
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

  bool _isBase(Service s) {
    final k = (s.kind ?? '').trim().toUpperCase();
    return k.isEmpty || k == 'BASE';
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

    final result = await nav.push<Object?>(
      MaterialPageRoute(
        builder: (_) => ServiceDetailsPage(repo: widget.repo, service: s),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Запись создана')));
      widget.onBookingCreated();
      _refreshSync(force: true);
      return;
    }

    if (result == 'waitlisted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавили в очередь ожидания')),
      );
      widget.onBookingCreated();
      _refreshSync(force: true);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

        final services =
            data.services.where((s) {
              final activeOk = (s.isActive ?? true) == true;
              return activeOk && _isBase(s);
            }).toList()..sort(
              (a, b) =>
                  (a.sortOrder ?? 100000).compareTo(b.sortOrder ?? 100000),
            );

        if (services.isEmpty) {
          return const EmptyState(
            icon: Icons.local_car_wash,
            title: 'Нет основных услуг',
            subtitle: 'Нет услуг типа BASE для отображения на этой странице.',
          );
        }

        final primary = cs.primary;

        return RefreshIndicator(
          onRefresh: _pullToRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(Icons.local_car_wash_rounded, color: primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Выбрать услугу',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface.withValues(alpha: 0.96),
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Открой услугу, посмотри детали и выбери удобный слот.',
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.66),
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Услуги',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withValues(alpha: 0.96),
                ),
              ),
              const SizedBox(height: 12),
              for (final s in services)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ServiceCard(
                    service: s,
                    image: _serviceThumb(s),
                    onTap: () => _openDetails(s),
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

class _ServiceCard extends StatelessWidget {
  final Service service;
  final ImageProvider image;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.50),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 6),
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ],
          ),
          child: SizedBox(
            height: 116,
            child: Row(
              children: [
                Container(
                  width: 122,
                  height: 116,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(22),
                    ),
                  ),
                  child: Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.local_car_wash_rounded,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          service.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface.withValues(alpha: 0.96),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PricePill(text: '${service.priceRub} ₽'),
                            _InfoPill(
                              icon: Icons.schedule_rounded,
                              text: '${service.durationMin ?? 30} мин',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: cs.onSurface.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String text;

  const _PricePill({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: cs.onSurface.withValues(alpha: 0.94),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.68)),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
