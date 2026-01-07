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
    if (n.contains('кузов')) {
      return const AssetImage('assets/images/services/kuzov_1080.jpg');
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
                  Text('Ошибка: ${snapshot.error}'),
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
            subtitle: 'Похоже, backend вернул пустой список услуг.',
          );
        }

        final primary = Theme.of(context).colorScheme.primary;

        return RefreshIndicator(
          onRefresh: _pullToRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выбери услугу и время',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Сначала открой услугу, затем нажми “Записаться”.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Услуги',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              // ✅ Карточки услуг: без кнопки "Записаться"
              ...services.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openDetails(s),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                            color: Colors.black.withValues(alpha: 0.04),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 118,
                              child: Image(
                                image: _serviceThumb(s),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  child: const Center(
                                    child: Icon(Icons.local_car_wash),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _priceLine(s),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Посмотреть > ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: primary.withValues(alpha: 0.85),
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
                );
              }),
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
