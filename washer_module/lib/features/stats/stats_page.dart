import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

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

  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await widget.api.stats(from: range.start, to: range.end);
      setState(() => data = res);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: range,
    );
    if (picked != null) {
      setState(() => range = picked);
      await _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final title = '${df.format(range.start)} — ${df.format(range.end)}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _pickRange,
                child: const Text('Период'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
          ],

          const SizedBox(height: 12),
          if (data != null) _StatsCard(data!),

          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : _load,
              child: const Text('Обновить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsCard(this.data);

  @override
  Widget build(BuildContext context) {
    final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final cars = totals['carsCompleted'] ?? 0;
    final earn = totals['earningsRub'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итого',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Помыл машин: $cars'),
          const SizedBox(height: 4),
          Text('Заработал: $earn ₽'),
        ],
      ),
    );
  }
}
