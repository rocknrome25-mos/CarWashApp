import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

class ClockPage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const ClockPage({super.key, required this.api, required this.store});

  @override
  State<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  bool loading = true;
  bool refreshing = false;
  String? error;

  bool noAssignment = false;

  Map<String, dynamic>? shift;
  DateTime? lastUpdated;

  Timer? _timer;
  static const _autoRefreshSec = 15;

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  @override
  void initState() {
    super.initState();
    _load(initial: true);

    _timer = Timer.periodic(const Duration(seconds: _autoRefreshSec), (
      _,
    ) async {
      if (!mounted) return;
      if (loading || refreshing) return;
      await _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false, bool silent = false}) async {
    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      if (!silent) error = null;
    });

    try {
      final s = await widget.api.getCurrentShift();
      if (!mounted) return;
      setState(() {
        shift = s;
        noAssignment = false;
        lastUpdated = DateTime.now();
      });
    } on WasherApiException catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        setState(() {
          noAssignment = true;
          shift = null;
          lastUpdated = DateTime.now();
        });
      } else {
        if (!silent) setState(() => error = e.toString());
      }
    } catch (e) {
      if (!silent && mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          refreshing = false;
        });
      }
    }
  }

  Future<void> _clockIn() async {
    try {
      await widget.api.clockIn();
      await _load();
      _snack('Clock-in отмечен');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _clockOut() async {
    try {
      await widget.api.clockOut();
      await _load();
      _snack('Clock-out отмечен');
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _YCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: cs.error),
                  const SizedBox(height: 8),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _load(),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (noAssignment) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _YCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.work_off, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Clock-in будет доступен\nпосле назначения на пост.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: refreshing ? null : () => _load(),
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final s = shift!;
    final clock = (s['clock'] as Map).cast<String, dynamic>();

    final canIn = _asBool(clock['canClockIn']);
    final canOut = _asBool(clock['canClockOut']);

    final inAt = _asDate(clock['clockInAt']);
    final outAt = _asDate(clock['clockOutAt']);

    final df = DateFormat('dd.MM HH:mm');

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          // верхняя “полоска” как у Яндекса: статус + обновление + refresh
          _YCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.access_time, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lastUpdated == null
                          ? 'Обновление…'
                          : 'Обновлено: ${DateFormat('HH:mm:ss').format(lastUpdated!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: refreshing ? null : () => _load(),
                    icon: refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Обновить',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          _YCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Сегодня',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RowLine(
                    label: 'Clock-in',
                    value: inAt == null ? '—' : df.format(inAt),
                  ),
                  const SizedBox(height: 6),
                  _RowLine(
                    label: 'Clock-out',
                    value: outAt == null ? '—' : df.format(outAt),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: canIn ? _clockIn : null,
                          child: const Text('Clock-in'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: canOut ? _clockOut : null,
                          child: const Text('Clock-out'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
