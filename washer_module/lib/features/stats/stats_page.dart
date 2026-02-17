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

class _StatsPageState extends State<StatsPage> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? data;

  _StatsPreset preset = _StatsPreset.week;

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

  Future<void> _load() async {
    final r = _rangeForPreset(preset);

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await widget.api.stats(from: r.start, to: r.end);
      setState(() => data = res);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final totals = (data?['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final cars = totals['carsCompleted'] ?? 0;
    final earn = totals['earningsRub'] ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(), // ✅ web refresh always works
        padding: const EdgeInsets.all(16),
        children: [
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
                    onSelected: (v) async {
                      if (!v) return;
                      setState(() => preset = p);
                      await _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          _YCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Итого • ${_presetTitle(preset)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RowLine(label: 'Помыл машин', value: '$cars'),
                  const SizedBox(height: 6),
                  _RowLine(label: 'Заработал', value: '$earn ₽'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  final String label;
  final String value;
  const _RowLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.70),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
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
