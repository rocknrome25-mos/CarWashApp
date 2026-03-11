import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

class ShiftPage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const ShiftPage({super.key, required this.api, required this.store});

  @override
  State<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends State<ShiftPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  bool refreshing = false;

  String? error;
  bool noAssignment = false;
  bool upcomingAssignment = false;

  Map<String, dynamic>? shift;
  Map<String, dynamic>? bookingsPayload;

  Timer? _timer;
  DateTime? _lastUpdatedAt;

  static const _autoRefreshSec = 20;

  late final AnimationController _introController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

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

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _load(initial: true).then((_) {
      if (mounted) _introController.forward();
    });

    _timer = Timer.periodic(const Duration(seconds: _autoRefreshSec), (
      _,
    ) async {
      if (!mounted) return;
      if (refreshing || loading) return;
      await _load(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _findTodayAssignedShift() async {
    final now = DateTime.now();
    final from = _startOfDay(now);
    final to = _endOfDay(now);

    final res = await widget.api.schedule(from: from, to: to);
    final list = (res['shifts'] as List? ?? [])
        .cast<Map>()
        .map((x) => x.cast<String, dynamic>())
        .toList();

    if (list.isEmpty) return null;

    bool isToday(Map<String, dynamic> s) {
      final start = DateTime.tryParse(
        (s['startAt'] ?? '').toString(),
      )?.toLocal();
      if (start == null) return false;
      return start.year == now.year &&
          start.month == now.month &&
          start.day == now.day;
    }

    int statusRank(String status) {
      switch (status.toUpperCase().trim()) {
        case 'PUBLISHED':
          return 0;
        case 'DRAFT':
          return 1;
        case 'ACTIVE':
          return 2;
        case 'PENDING_PAYMENT':
          return 3;
        case 'COMPLETED':
          return 4;
        case 'CANCELED':
          return 9;
        default:
          return 8;
      }
    }

    final candidates = list.where((s) {
      if (!isToday(s)) return false;
      final status = (s['status'] ?? '').toString().toUpperCase().trim();
      return status != 'CANCELED';
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final sa = statusRank((a['status'] ?? '').toString());
      final sb = statusRank((b['status'] ?? '').toString());
      if (sa != sb) return sa.compareTo(sb);

      final da =
          DateTime.tryParse((a['startAt'] ?? '').toString())?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db =
          DateTime.tryParse((b['startAt'] ?? '').toString())?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final nowDiffA = da.difference(now).inMinutes.abs();
      final nowDiffB = db.difference(now).inMinutes.abs();
      if (nowDiffA != nowDiffB) return nowDiffA.compareTo(nowDiffB);

      return da.compareTo(db);
    });

    return _normalizeScheduledShift(candidates.first);
  }

  Map<String, dynamic> _normalizeScheduledShift(Map<String, dynamic> raw) {
    final start = DateTime.tryParse(
      (raw['startAt'] ?? '').toString(),
    )?.toLocal();
    final end = DateTime.tryParse((raw['endAt'] ?? '').toString())?.toLocal();
    final now = DateTime.now();

    String shiftState;
    if (start != null &&
        end != null &&
        now.isAfter(start) &&
        now.isBefore(end)) {
      shiftState = 'ACTIVE';
    } else if (start != null && now.isBefore(start)) {
      shiftState = 'SCHEDULED';
    } else {
      shiftState = (raw['status'] ?? 'PUBLISHED')
          .toString()
          .toUpperCase()
          .trim();
    }

    return <String, dynamic>{
      ...raw,
      '_source': 'schedule',
      '_upcoming': start != null && now.isBefore(start),
      '_normalizedStatus': shiftState,
      'bayId': raw['bayId'] ?? raw['plannedBayId'] ?? '—',
      'totals': {'carsCompleted': 0, 'earningsRub': 0},
    };
  }

  Future<void> _load({bool initial = false, bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      if (!silent) {
        error = null;
        noAssignment = false;
        upcomingAssignment = false;
      }
    });

    try {
      final s = await widget.api.getCurrentShift();

      Map<String, dynamic>? b;
      try {
        b = await widget.api.getCurrentShiftBookings();
      } on WasherApiException catch (e) {
        if (e.status != 404) rethrow;
        b = {'bookings': <Map<String, dynamic>>[]};
      }

      if (!mounted) return;
      setState(() {
        shift = s;
        bookingsPayload = b ?? {'bookings': <Map<String, dynamic>>[]};
        _lastUpdatedAt = DateTime.now();
        noAssignment = false;
        upcomingAssignment = false;
        error = null;
      });
    } on WasherApiException catch (e) {
      if (!mounted) return;

      if (e.status == 404) {
        try {
          final fallbackShift = await _findTodayAssignedShift();

          if (!mounted) return;

          if (fallbackShift != null) {
            setState(() {
              shift = fallbackShift;
              bookingsPayload = {'bookings': <Map<String, dynamic>>[]};
              _lastUpdatedAt = DateTime.now();
              noAssignment = false;
              upcomingAssignment =
                  (fallbackShift['_upcoming'] == true) ||
                  ((fallbackShift['_normalizedStatus'] ?? '') == 'SCHEDULED');
              error = null;
            });
          } else {
            setState(() {
              noAssignment = true;
              upcomingAssignment = false;
              error = null;
              shift = null;
              bookingsPayload = null;
              _lastUpdatedAt = DateTime.now();
            });
          }
        } catch (fallbackError) {
          if (!mounted) return;
          if (!silent) {
            setState(() => error = fallbackError.toString());
          }
        }
      } else {
        if (!silent) {
          setState(() => error = e.toString());
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          refreshing = false;
        });
      }
    }
  }

  int _statusRank(String status) {
    final s = status.toUpperCase().trim();
    switch (s) {
      case 'ACTIVE':
        return 0;
      case 'PENDING_PAYMENT':
        return 1;
      case 'COMPLETED':
        return 2;
      case 'CANCELED':
        return 3;
      case 'SCHEDULED':
        return 4;
      case 'PUBLISHED':
        return 5;
      case 'DRAFT':
        return 6;
      default:
        return 9;
    }
  }

  _StatusUi _statusUi(String status, ColorScheme cs) {
    final s = status.toUpperCase().trim();
    switch (s) {
      case 'ACTIVE':
        return _StatusUi(
          label: 'В работе',
          icon: Icons.play_circle_filled_rounded,
          bg: cs.primaryContainer.withValues(alpha: 0.70),
          fg: cs.onPrimaryContainer,
        );
      case 'PENDING_PAYMENT':
        return _StatusUi(
          label: 'Ожидает',
          icon: Icons.schedule_rounded,
          bg: cs.tertiaryContainer.withValues(alpha: 0.70),
          fg: cs.onTertiaryContainer,
        );
      case 'COMPLETED':
        return _StatusUi(
          label: 'Готово',
          icon: Icons.check_circle_rounded,
          bg: cs.secondaryContainer.withValues(alpha: 0.70),
          fg: cs.onSecondaryContainer,
        );
      case 'CANCELED':
        return _StatusUi(
          label: 'Отменено',
          icon: Icons.cancel_rounded,
          bg: cs.errorContainer.withValues(alpha: 0.70),
          fg: cs.onErrorContainer,
        );
      case 'SCHEDULED':
        return _StatusUi(
          label: 'Назначена',
          icon: Icons.event_available_rounded,
          bg: cs.secondaryContainer.withValues(alpha: 0.70),
          fg: cs.onSecondaryContainer,
        );
      case 'PUBLISHED':
        return _StatusUi(
          label: 'Опубликована',
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
      default:
        return _StatusUi(
          label: status,
          icon: Icons.help_outline_rounded,
          bg: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          fg: cs.onSurface,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (loading) return const Center(child: CircularProgressIndicator());

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
              if (error != null)
                _YCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: cs.error.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(Icons.error_outline, color: cs.error),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Не удалось загрузить смену',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: _ScaleTap(
                            child: FilledButton.icon(
                              onPressed: () => _load(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Повторить'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (noAssignment)
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
                          child: Icon(Icons.work_off, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Смена не назначена',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Записи появятся после назначения на пост.',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface.withValues(alpha: 0.80),
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
                )
              else if (shift != null)
                ..._buildShift(context, cs)
              else
                _YCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Нет данных по смене.',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildShift(BuildContext context, ColorScheme cs) {
    final textTheme = Theme.of(context).textTheme;
    final s = shift!;

    final totalsRaw = (s['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final carsCompleted = totalsRaw['carsCompleted'] ?? 0;
    final earningsRub = totalsRaw['earningsRub'] ?? 0;

    final rawBookings = (bookingsPayload?['bookings'] as List? ?? [])
        .cast<Map>()
        .map((x) => x.cast<String, dynamic>())
        .toList();

    rawBookings.sort((a, b) {
      final ra = _statusRank((a['status'] ?? '').toString());
      final rb = _statusRank((b['status'] ?? '').toString());
      if (ra != rb) return ra.compareTo(rb);
      final da =
          DateTime.tryParse((a['dateTime'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db =
          DateTime.tryParse((b['dateTime'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return da.compareTo(db);
    });

    final dfTime = DateFormat('HH:mm');
    final dfDate = DateFormat('dd.MM');
    final last = _lastUpdatedAt;

    final start = DateTime.tryParse((s['startAt'] ?? '').toString())?.toLocal();
    final end = DateTime.tryParse((s['endAt'] ?? '').toString())?.toLocal();
    final bayId = s['bayId'] ?? s['plannedBayId'] ?? '—';
    final normalizedStatus = (s['_normalizedStatus'] ?? s['status'] ?? '')
        .toString();

    final timeText = start == null
        ? 'Время не указано'
        : '${dfTime.format(start)}'
              '${end != null ? '—${dfTime.format(end)}' : ''}';

    return [
      _YCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.work_outline_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.store.name ?? 'Мойщик'} • Пост $bayId',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      upcomingAssignment
                          ? 'Вам назначена смена на сегодня'
                          : 'Текущая рабочая смена и записи по вашему посту',
                      style: textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Pill(icon: Icons.schedule_rounded, text: timeText),
                        _Pill(
                          icon: Icons.local_car_wash_rounded,
                          text: 'Помыл: $carsCompleted',
                        ),
                        _Pill(
                          icon: Icons.payments_outlined,
                          text: 'Заработал: $earningsRub ₽',
                        ),
                        _StatusBadge(statusUi: _statusUi(normalizedStatus, cs)),
                      ],
                    ),
                    if (upcomingAssignment) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.42),
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
                                color: cs.onSecondaryContainer.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Смена уже назначена на сегодня. Записи по посту появятся, когда смена станет текущей.',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            last == null
                                ? 'Обновление…'
                                : 'Обновлено: ${DateFormat('HH:mm:ss').format(last)}',
                            style: textTheme.bodySmall?.copyWith(
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          tooltip: 'Обновить',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'Записи',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _Pill(icon: Icons.timer_outlined, text: 'Авто: ${_autoRefreshSec}s'),
        ],
      ),
      const SizedBox(height: 10),
      if (rawBookings.isEmpty)
        _YCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
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
                    upcomingAssignment
                        ? 'Смена назначена, но записи появятся после начала текущей смены.'
                        : 'Пока нет записей по этому посту или смене.',
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
      for (final b in rawBookings) ...[
        const SizedBox(height: 10),
        _YCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _BookingTile(
              b: b,
              dfTime: dfTime,
              dfDate: dfDate,
              statusUi: _statusUi((b['status'] ?? '').toString(), cs),
            ),
          ),
        ),
      ],
    ];
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

class _StatusBadge extends StatelessWidget {
  final _StatusUi statusUi;

  const _StatusBadge({required this.statusUi});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: statusUi.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
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
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> b;
  final DateFormat dfTime;
  final DateFormat dfDate;
  final _StatusUi statusUi;

  const _BookingTile({
    required this.b,
    required this.dfTime,
    required this.dfDate,
    required this.statusUi,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dt = DateTime.tryParse((b['dateTime'] ?? '').toString())?.toLocal();

    final car = (b['car'] as Map?)?.cast<String, dynamic>() ?? {};
    final service = (b['service'] as Map?)?.cast<String, dynamic>() ?? {};
    final addons = (b['addons'] as List? ?? [])
        .cast<Map>()
        .map((x) => x.cast<String, dynamic>())
        .toList();

    final plate = (car['plateDisplay'] ?? '').toString();
    final title =
        '${dt != null ? dfTime.format(dt) : ''}'
        '${plate.isNotEmpty ? ' • $plate' : ''}';

    final subtitle = '${car['makeDisplay'] ?? ''} ${car['modelDisplay'] ?? ''}'
        .trim();

    final comment = (b['comment'] ?? '').toString().trim();
    final adminNote = (b['adminNote'] ?? '').toString().trim();

    final addonsText = addons
        .map((a) => (a['service']?['name'] ?? '').toString().trim())
        .where((x) => x.isNotEmpty)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.isEmpty ? 'Запись' : title,
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
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if ((service['name'] ?? '').toString().isNotEmpty)
              _Pill(
                icon: Icons.local_car_wash_rounded,
                text: 'Услуга: ${service['name']}',
              ),
            if (addons.isNotEmpty)
              _Pill(
                icon: Icons.add_circle_outline_rounded,
                text: 'Доп: ${addons.length}',
              ),
            if (dt != null)
              _Pill(
                icon: Icons.calendar_month_rounded,
                text: dfDate.format(dt),
              ),
          ],
        ),
        if (addonsText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Доп. услуги: $addonsText',
            style: textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.74),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (adminNote.isNotEmpty || comment.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.50),
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
                    color: cs.onSecondaryContainer.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notes_rounded,
                    size: 18,
                    color: cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Инструкции',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer.withValues(
                            alpha: 0.85,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (adminNote.isNotEmpty)
                        Text(
                          adminNote,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Комментарий клиента: $comment',
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSecondaryContainer.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ],
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