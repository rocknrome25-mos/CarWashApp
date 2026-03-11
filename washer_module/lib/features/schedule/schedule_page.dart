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

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool refreshing = false;
  String? error;

  List<Map<String, dynamic>> shifts = [];
  Map<String, dynamic>? adminOnDuty;

  Timer? _timer;
  DateTime? _lastUpdatedAt;

  static const _autoRefreshSec = 45;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _from => _startOfDay(DateTime.now());

  DateTime get _to => _startOfDay(DateTime.now().add(const Duration(days: 8)));

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

    _load(initial: true).then((_) {
      if (mounted) _introController.forward();
    });

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
    _introController.dispose();
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

      if (!mounted) return;
      setState(() {
        shifts = list;
        adminOnDuty = admin;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (e) {
      if (!silent && mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (!mounted) return;
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
    final raw = df.format(d);
    if (raw.isEmpty) return 'День';

    return raw[0].toUpperCase() + raw.substring(1);
  }

  _StatusUi _statusUi(String status, ColorScheme cs) {
    final s = status.toUpperCase().trim();
    switch (s) {
      case 'PUBLISHED':
        return _StatusUi(
          label: 'Опубликовано',
          icon: Icons.verified_rounded,
          bg: cs.secondaryContainer.withValues(alpha: 0.70),
          fg: cs.onSecondaryContainer,
        );
      case 'DRAFT':
        return _StatusUi(
          label: 'Черновик',
          icon: Icons.edit_note_rounded,
          bg: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          fg: cs.onSurface,
        );
      case 'CANCELED':
        return _StatusUi(
          label: 'Отменено',
          icon: Icons.cancel_rounded,
          bg: cs.errorContainer.withValues(alpha: 0.72),
          fg: cs.onErrorContainer,
        );
      default:
        return _StatusUi(
          label: status,
          icon: Icons.help_outline_rounded,
          bg: cs.surfaceContainerHighest.withValues(alpha: 0.55),
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
    final textTheme = Theme.of(context).textTheme;
    final dfTime = DateFormat('HH:mm');

    if (loading) return const Center(child: CircularProgressIndicator());

    final groups = <DateTime, List<Map<String, dynamic>>>{};
    final undated = <Map<String, dynamic>>[];

    for (final s in shifts) {
      final start = DateTime.tryParse(
        (s['startAt'] ?? '').toString(),
      )?.toLocal();

      if (start == null) {
        undated.add(s);
        continue;
      }

      final d = DateTime(start.year, start.month, start.day);
      groups.putIfAbsent(d, () => []).add(s);
    }

    for (final entry in groups.entries) {
      entry.value.sort((a, b) {
        final da =
            DateTime.tryParse((a['startAt'] ?? '').toString())?.toLocal() ??
            DateTime(1970);
        final db =
            DateTime.tryParse((b['startAt'] ?? '').toString())?.toLocal() ??
            DateTime(1970);

        final cmpStatus = _statusRank(
          (a['status'] ?? '').toString(),
        ).compareTo(_statusRank((b['status'] ?? '').toString()));
        if (cmpStatus != 0) return cmpStatus;

        return da.compareTo(db);
      });
    }

    final days = groups.keys.toList()..sort((a, b) => a.compareTo(b));

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _YCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Расписание',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _lastUpdatedAt == null
                                  ? 'Обновление…'
                                  : 'Обновлено: ${DateFormat('HH:mm:ss').format(_lastUpdatedAt!)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: refreshing ? null : () => _load(),
                        icon: refreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        tooltip: 'Обновить',
                      ),
                    ],
                  ),
                ),
              ),

              if (adminOnDuty != null) ...[
                const SizedBox(height: 12),
                _YCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
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
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.70),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${adminOnDuty!['name'] ?? ''}',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${adminOnDuty!['phone'] ?? ''}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _ScaleTap(
                          child: FilledButton.icon(
                            onPressed: () => _callAdmin(
                              (adminOnDuty!['phone'] ?? '').toString(),
                            ),
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('Позвонить'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 12),
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
              ],

              const SizedBox(height: 14),

              if (shifts.isEmpty)
                _YCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.inbox_outlined,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'На ближайшую неделю смен нет.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.78),
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
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 26,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dayHeader(day),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final s in groups[day]!) ...[
                  _YCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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

              if (undated.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 26,
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Смены без даты',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final s in undated) ...[
                  _YCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
        ),
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
    final textTheme = Theme.of(context).textTheme;

    final start = DateTime.tryParse((s['startAt'] ?? '').toString())?.toLocal();
    final end = DateTime.tryParse((s['endAt'] ?? '').toString())?.toLocal();

    final loc = (s['location'] as Map?)?.cast<String, dynamic>();
    final washName = (loc?['name'] ?? '').toString().trim();
    final washAddress = (loc?['address'] ?? '').toString().trim();

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
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: statusUi.bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusUi.icon, size: 16, color: statusUi.fg),
                  const SizedBox(width: 6),
                  Text(
                    statusUi.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: statusUi.fg,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (washName.isNotEmpty)
              _Pill(
                icon: Icons.local_car_wash_rounded,
                text: 'Мойка: $washName',
              ),
            if (plannedBayId != null)
              _Pill(icon: Icons.grid_view_rounded, text: 'Пост: $plannedBayId'),
            if (washAddress.isNotEmpty)
              _Pill(
                icon: Icons.place_outlined,
                text: 'Адрес мойки: $washAddress',
              ),
          ],
        ),
        if (showNote) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.50),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notes_rounded, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    noteRaw.trim(),
                    style: textTheme.bodyMedium?.copyWith(
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

class _ScaleTap extends StatefulWidget {
  final Widget child;

  const _ScaleTap({required this.child});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.82)),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.90),
            ),
          ),
        ],
      ),
    );
  }
}
