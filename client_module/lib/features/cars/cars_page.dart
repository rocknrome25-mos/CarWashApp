import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/car.dart';
import 'add_car_sheet.dart';

class CarsPage extends StatefulWidget {
  final AppRepository repo;

  const CarsPage({super.key, required this.repo});

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  late Future<List<Car>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getCars();
  }

  void _refresh({bool force = false}) {
    setState(() {
      _future = widget.repo.getCars(forceRefresh: force);
    });
  }

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
      _refresh(force: true);
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
        content: const Text('Авто будет удалено из профиля.'),
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

    if (!mounted) return;
    if (ok != true) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.repo.deleteCar(carId);
      if (!mounted) return;
      _refresh(force: true);
      messenger.showSnackBar(const SnackBar(content: Text('Авто удалено')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  // ---------- UI blocks ----------

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset(
                  'assets/images/cars/incognito.png', // ✅ твой новый ассет
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.directions_car,
                    size: 54,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Нет авто',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Добавь машину, чтобы записываться на услуги.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _addCar,
                icon: const Icon(Icons.add),
                label: const Text('Добавить авто'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _carThumbAsset(Car c) {
    // ✅ если у тебя в модели есть avatarAsset — можно оставлять,
    // но ты просил использовать новые:
    final body = (c.bodyType ?? '').toLowerCase();
    if (body.contains('suv') ||
        body.contains('внед') ||
        body.contains('крос')) {
      return 'assets/images/cars/suv.png';
    }
    if (body.contains('sedan') || body.contains('седан')) {
      return 'assets/images/cars/sedan.png';
    }
    // fallback
    return 'assets/images/cars/sedan.png';
  }

  Widget _pill(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onSurface.withValues(alpha: 0.90),
        ),
      ),
    );
  }

  Widget _carTile(Car c) {
    final cs = Theme.of(context).colorScheme;

    final makeModel = (c.title.trim().isEmpty ? 'Авто' : c.title.trim());
    final plate = c.plateDisplay.trim();
    final body = (c.bodyType ?? '').trim();
    final color = (c.color ?? '').trim();
    final year = c.year;

    final chips = <String>[];
    if (plate.isNotEmpty) chips.add(plate);
    if (body.isNotEmpty) chips.add(body.toUpperCase());
    if (color.isNotEmpty) chips.add(color);
    if (year != null && year > 0) chips.add(year.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: 0.22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row (delete)
          Row(
            children: [
              const Spacer(),
              IconButton(
                tooltip: 'Удалить авто',
                onPressed: () => _confirmDeleteCar(c.id),
                icon: Icon(
                  Icons.delete_outline,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
            ],
          ),

          // image (square)
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  _carThumbAsset(c),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.directions_car,
                    size: 48,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            makeModel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 6),

          if (chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.take(3).map(_pill).toList(),
            ),
        ],
      ),
    );
  }

  int _gridCountForWidth(double w) {
    // красиво: 1 колонка на узком, 2 на среднем, 3 на широком
    if (w < 420) return 1;
    if (w < 900) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Car>>(
      future: _future,
      builder: (context, snapshot) {
        final cs = Theme.of(context).colorScheme;

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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _refresh(force: true),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }

        final cars = snapshot.data ?? const <Car>[];

        // ✅ ВАЖНО: FAB скрываем, когда пусто (чтобы не было “двух плюсов”)
        final showFab = cars.isNotEmpty;

        if (cars.isEmpty) {
          return Scaffold(body: _emptyState(), floatingActionButton: null);
        }

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => _refresh(force: true),
            child: LayoutBuilder(
              builder: (ctx, c) {
                final crossAxisCount = _gridCountForWidth(c.maxWidth);

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: cars.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05, // почти квадрат
                  ),
                  itemBuilder: (_, i) => _carTile(cars[i]),
                );
              },
            ),
          ),
          floatingActionButton: showFab
              ? FloatingActionButton(
                  onPressed: _addCar,
                  tooltip: 'Добавить авто',
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}
