import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

class SchedulePage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const SchedulePage({super.key, required this.api, required this.store});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool loading = true;
  bool refreshing = false;
  String? error;

  List<Map<String, dynamic>> shifts = [];
  Map<String, dynamic>? adminOnDuty;

  Timer? _timer;
  DateTime? _lastUpdatedAt;

  static const _autoRefreshSec = 45;

  DateTime get _from => DateTime.now();
  DateTime get _to => DateTime.now().add(const Duration(days: 7));

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

  int _statusRank(String status) {
    final s = status.toUpperCase().trim();
    switch (s) {
      case 'PUBLISHED':
        return 0;
      case 'DRAFT':
        return 1;
      case 'CANCELED':
        return 2;
      default:
        return 9;
    }
  }

  Future<void> _load({bool initial = false, bool silent = false}) async {
    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      if (!silent) error = null;
    });

    try {
      // schedule
      final res = await widget.api.schedule(from: _from, to: _to);
      final list = (res['shifts'] as List? ?? [])
          .cast<Map>()
          .map((x) => x.cast<String, dynamic>())
          .toList();

      list.sort((a, b) {
        final sa = (a['status'] ?? '').toString();
        final sb = (b['status'] ?? '').toString();

        final da =
            DateTime.tryParse((a['startAt'] ?? '').toString())?.toLocal() ??
            DateTime(1970);
        final db =
            DateTime.tryParse((b['startAt'] ?? '').toString())?.toLocal() ??
            DateTime(1970);

        final dayA = DateTime(da.year, da.month, da.day);
        final dayB = DateTime(db.year, db.month, db.day);

        final cmpDay = dayA.compareTo(dayB);
        if (cmpDay != 0) return cmpDay;

        final cmpStatus = _statusRank(sa).compareTo(_statusRank(sb));
        if (cmpStatus != 0) return cmpStatus;

        return da.compareTo(db);
      });

      // admin contact (optional)
      Map<String, dynamic>? admin;
      try {
        final cs = await widget.api.getCurrentShift();
        final a = (cs['adminOnDuty'] as Map?)?.cast<String, dynamic>();
        if (a != null && (a['phone'] ?? '').toString().isNotEmpty) {
          admin = a;
        }
      } catch (_) {
        // ignore
      }

      setState(() {
        shifts = list;
        adminOnDuty = admin;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (e) {
      if (!silent) setState(() => error = e.toString());
    } finally {
      setState(() {
        loading = false;
        refreshing = false;
      });
    }
  }

  String _dayHeader(DateTime d) {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final d0 = DateTime(d.year, d.month, d.day);

    final diff = d0.difference(t0).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Завтра';

    final df = DateFormat('EEE, dd.MM', 'ru');
    return df.format(d);
  }

  _StatusUi _statusUi(String status, ColorScheme cs) {
    final s = status.toUpperCase().trim();
    switch (s) {
      case 'PUBLISHED':
        return _StatusUi(
          label: 'Опубликовано',
          icon: Icons.verified,
          bg: cs.secondaryContainer.withValues(alpha: 0.65),
          fg: cs.onSecondaryContainer,
        );
      case 'DRAFT':
        return _StatusUi(
          label: 'Черновик',
          icon: Icons.edit_note,
          bg: cs.surfaceContainerHighest.withValues(alpha: 0.50),
          fg: cs.onSurface,
        );
      case 'CANCELED':
        return _StatusUi(
          label: 'Отменено',
          icon: Icons.cancel,
          bg: cs.errorContainer.withValues(alpha: 0.65),
          fg: cs.onErrorContainer,
        );
      default:
        return _StatusUi(
          label: status,
          icon: Icons.help_outline,
          bg: cs.surfaceContainerHighest.withValues(alpha: 0.50),
          fg: cs.onSurface,
        );
    }
  }

  Future<void> _callAdmin(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    final uri = Uri.parse('tel:$p');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dfTime = DateFormat('HH:mm');

    if (loading) return const Center(child: CircularProgressIndicator());

    // group by day
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final s in shifts) {
      final start = DateTime.tryParse(
        (s['startAt'] ?? '').toString(),
      )?.toLocal();
      final d = start == null
          ? DateTime(1970)
          : DateTime(start.year, start.month, start.day);
      groups.putIfAbsent(d, () => []).add(s);
    }
    final days = groups.keys.toList()..sort((a, b) => a.compareTo(b));

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(), // ✅ web refresh always works
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if (adminOnDuty != null) ...[
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
                      child: Icon(Icons.support_agent, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Админ смены',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.70),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${adminOnDuty!['name'] ?? ''}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${adminOnDuty!['phone'] ?? ''}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () =>
                          _callAdmin((adminOnDuty!['phone'] ?? '').toString()),
                      child: const Text('Позвонить'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              Expanded(
                child: Text(
                  _lastUpdatedAt == null
                      ? 'Обновление…'
                      : 'Обновлено: ${DateFormat('HH:mm:ss').format(_lastUpdatedAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
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

          if (error != null) ...[
            const SizedBox(height: 10),
            _YCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error!)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          if (shifts.isEmpty)
            _YCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'На ближайшую неделю смен нет.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          for (final day in days) ...[
            const SizedBox(height: 14),
            Text(
              _dayHeader(day),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final s in groups[day]!) ...[
              _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _ShiftTile(
                    s: s,
                    dfTime: dfTime,
                    statusUi: _statusUi((s['status'] ?? '').toString(), cs),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final Map<String, dynamic> s;
  final DateFormat dfTime;
  final _StatusUi statusUi;

  const _ShiftTile({
    required this.s,
    required this.dfTime,
    required this.statusUi,
  });

  bool _looksLikeGarbage(String note) {
    final t = note.trim();
    if (t.isEmpty) return true;
    final q = '?'.allMatches(t).length;
    if (t.length >= 6 && q / t.length > 0.25) return true;
    final hasLettersOrDigits = RegExp(r'[A-Za-zА-Яа-я0-9]').hasMatch(t);
    if (!hasLettersOrDigits) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final start = DateTime.tryParse((s['startAt'] ?? '').toString())?.toLocal();
    final end = DateTime.tryParse((s['endAt'] ?? '').toString())?.toLocal();

    final loc = (s['location'] as Map?)?.cast<String, dynamic>();
    final locName = (loc?['name'] ?? '').toString();
    final locAddr = (loc?['address'] ?? '').toString();

    final plannedBayId = s['plannedBayId'];
    final noteRaw = (s['note'] ?? '').toString();
    final showNote = !_looksLikeGarbage(noteRaw);

    final title = start == null
        ? 'Смена'
        : '${dfTime.format(start)}—${end != null ? dfTime.format(end) : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: statusUi.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusUi.icon, size: 16, color: statusUi.fg),
                  const SizedBox(width: 6),
                  Text(
                    statusUi.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusUi.fg,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (locName.isNotEmpty)
              _Pill(icon: Icons.place_outlined, text: locName),
            if (plannedBayId != null)
              _Pill(icon: Icons.local_car_wash, text: 'Пост: $plannedBayId'),
            if (locAddr.isNotEmpty)
              _Pill(icon: Icons.map_outlined, text: locAddr),
          ],
        ),
        if (showNote) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, color: cs.onSurface.withValues(alpha: 0.8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    noteRaw.trim(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusUi {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;

  _StatusUi({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
  });
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
