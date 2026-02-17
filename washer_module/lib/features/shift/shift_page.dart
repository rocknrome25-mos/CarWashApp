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

class _ShiftPageState extends State<ShiftPage> {
  bool loading = true;
  bool refreshing = false;

  String? error;
  bool noAssignment = false;

  Map<String, dynamic>? shift;
  Map<String, dynamic>? bookingsPayload;

  Timer? _timer;
  DateTime? _lastUpdatedAt;

  static const _autoRefreshSec = 20;

  @override
  void initState() {
    super.initState();
    _load(initial: true);

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
    super.dispose();
  }

  Future<void> _load({bool initial = false, bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      if (!silent) {
        error = null;
        noAssignment = false;
      }
    });

    try {
      final s = await widget.api.getCurrentShift();
      final b = await widget.api.getCurrentShiftBookings();

      if (!mounted) return;
      setState(() {
        shift = s;
        bookingsPayload = b;
        _lastUpdatedAt = DateTime.now();
        noAssignment = false;
        error = null;
      });
    } on WasherApiException catch (e) {
      if (!mounted) return;

      if (e.status == 404) {
        setState(() {
          noAssignment = true;
          error = null;
          shift = null;
          bookingsPayload = null;
          _lastUpdatedAt = DateTime.now();
        });
      } else {
        if (!silent) setState(() => error = e.toString());
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
          icon: Icons.play_circle_filled,
          bg: cs.primaryContainer.withValues(alpha: 0.65),
          fg: cs.onPrimaryContainer,
        );
      case 'PENDING_PAYMENT':
        return _StatusUi(
          label: 'Ожидает',
          icon: Icons.schedule,
          bg: cs.tertiaryContainer.withValues(alpha: 0.65),
          fg: cs.onTertiaryContainer,
        );
      case 'COMPLETED':
        return _StatusUi(
          label: 'Готово',
          icon: Icons.check_circle,
          bg: cs.secondaryContainer.withValues(alpha: 0.65),
          fg: cs.onSecondaryContainer,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) return const Center(child: CircularProgressIndicator());

    // ✅ RefreshIndicator must wrap a scrollable with AlwaysScrollable physics (for Web)
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if (error != null)
            _YCard(
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
            )
          else if (noAssignment)
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
                      child: Icon(Icons.work_off, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Смена не назначена.\nЗаписи появятся после назначения на пост.',
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
            )
          else
            ..._buildShift(context, cs),
        ],
      ),
    );
  }

  List<Widget> _buildShift(BuildContext context, ColorScheme cs) {
    final s = shift!;
    final totals = (s['totals'] as Map).cast<String, dynamic>();

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

    return [
      _YCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.work_outline, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.store.name ?? 'Мойщик'} • Пост ${s['bayId']}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Pill(
                          icon: Icons.local_car_wash,
                          text: 'Помыл: ${totals['carsCompleted']}',
                        ),
                        _Pill(
                          icon: Icons.payments_outlined,
                          text: 'Заработал: ${totals['earningsRub']} ₽',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            last == null
                                ? 'Обновление…'
                                : 'Обновлено: ${DateFormat('HH:mm:ss').format(last)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          _Pill(icon: Icons.timer_outlined, text: 'Авто: ${_autoRefreshSec}s'),
        ],
      ),
      const SizedBox(height: 10),
      if (rawBookings.isEmpty)
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
                    'Пока нет записей по этому посту/смене.',
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
      for (final b in rawBookings) ...[
        const SizedBox(height: 10),
        _YCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
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
    final dt = DateTime.tryParse(b['dateTime'].toString())?.toLocal();

    final car = (b['car'] as Map).cast<String, dynamic>();
    final service = (b['service'] as Map).cast<String, dynamic>();
    final addons = (b['addons'] as List? ?? [])
        .cast<Map>()
        .map((x) => x.cast<String, dynamic>())
        .toList();

    final title =
        '${dt != null ? dfTime.format(dt) : ''} • ${car['plateDisplay'] ?? ''}';
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
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Pill(
              icon: Icons.local_car_wash,
              text: 'Услуга: ${service['name']}',
            ),
            if (addons.isNotEmpty)
              _Pill(
                icon: Icons.add_circle_outline,
                text: 'Доп: ${addons.length}',
              ),
            if (dt != null)
              _Pill(icon: Icons.calendar_month, text: dfDate.format(dt)),
          ],
        ),
        if (addonsText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Доп. услуги: $addonsText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, color: cs.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Инструкции',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSecondaryContainer,
                              ),
                        ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Комментарий клиента: $comment',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
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
