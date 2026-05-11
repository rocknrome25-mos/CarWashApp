import 'package:flutter/material.dart';
import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

enum _StatsPreset { day, week, month, all }

class StatsPage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const StatsPage({super.key, required this.api, required this.store});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  bool loading = false;
  String? error;
  Map<String, dynamic>? data;

  _StatsPreset preset = _StatsPreset.week;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTimeRange _rangeForPreset(_StatsPreset p) {
    final now = DateTime.now();
    switch (p) {
      case _StatsPreset.day:
        return DateTimeRange(start: _startOfDay(now), end: now);
      case _StatsPreset.week:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case _StatsPreset.month:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case _StatsPreset.all:
        return DateTimeRange(start: DateTime(2000, 1, 1), end: now);
    }
  }

  String _presetTitle(_StatsPreset p) {
    switch (p) {
      case _StatsPreset.day:
        return 'День';
      case _StatsPreset.week:
        return 'Неделя';
      case _StatsPreset.month:
        return 'Месяц';
      case _StatsPreset.all:
        return 'Всего';
    }
  }

  String _presetSubtitle(_StatsPreset p) {
    switch (p) {
      case _StatsPreset.day:
        return 'Статистика за текущий день';
      case _StatsPreset.week:
        return 'Статистика за последние 7 дней';
      case _StatsPreset.month:
        return 'Статистика за последние 30 дней';
      case _StatsPreset.all:
        return 'Статистика за всё время';
    }
  }

  Future<void> _load() async {
    final r = _rangeForPreset(preset);

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await widget.api.stats(from: r.start, to: r.end);
      if (!mounted) return;
      setState(() => data = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnim = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
        );

    _load().then((_) {
      if (mounted) _introController.forward();
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totals = (data?['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final cars = totals['carsCompleted'] ?? 0;
    final earn = totals['earningsRub'] ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.bar_chart_rounded, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Статистика',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _presetSubtitle(preset),
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.68),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _StatsPreset.values.map((p) {
                    final selected = p == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(_presetTitle(p)),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (v) async {
                          if (!v) return;
                          setState(() => preset = p);
                          await _load();
                        },
                        labelStyle: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? cs.onSecondaryContainer
                              : cs.onSurface.withValues(alpha: 0.86),
                        ),
                        side: BorderSide(
                          color: selected
                              ? cs.secondaryContainer
                              : cs.outlineVariant.withValues(alpha: 0.55),
                        ),
                        selectedColor: cs.secondaryContainer,
                        backgroundColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              if (loading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(minHeight: 5),
                ),
                const SizedBox(height: 14),
              ],

              if (error != null) ...[
                _YCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cs.error.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.error_outline, color: cs.error),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Row(
                children: [
                  Expanded(
                    child: _StatMiniCard(
                      icon: Icons.local_car_wash_rounded,
                      title: 'Помыл машин',
                      value: '$cars',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatMiniCard(
                      icon: Icons.payments_outlined,
                      title: 'Заработал',
                      value: '$earn ₽',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Итого • ${_presetTitle(preset)}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Сводные показатели по выполненным работам',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.30,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          children: [
                            _RowLine(
                              label: 'Помыл машин',
                              value: '$cars',
                              icon: Icons.local_car_wash_rounded,
                            ),
                            const SizedBox(height: 10),
                            _RowLine(
                              label: 'Заработал',
                              value: '$earn ₽',
                              icon: Icons.payments_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatMiniCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RowLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _YCard extends StatelessWidget {
  final Widget child;
  const _YCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.58)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: child,
    );
  }
}
