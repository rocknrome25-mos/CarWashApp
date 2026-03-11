import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import '../../core/storage/session_store.dart';

class WashersPage extends StatefulWidget {
  final AdminApiClient api;
  final SessionStore store;
  final AdminSession session;

  const WashersPage({
    super.key,
    required this.api,
    required this.store,
    required this.session,
  });

  @override
  State<WashersPage> createState() => _WashersPageState();
}

class _WashersPageState extends State<WashersPage> {
  bool loading = true;

  String? plannedError;
  String? washersError;

  List<Map<String, dynamic>> planned = [];
  List<Map<String, dynamic>> washers = [];

  int selectedDayIndex = 0;
  bool showCanceled = false;

  DateTime _todayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _from => _todayOnly(DateTime.now());

  DateTime get _to =>
      _todayOnly(DateTime.now().add(const Duration(days: 7))).add(
        const Duration(days: 1),
      );

  @override
  void initState() {
    super.initState();
    load();
  }

  DateTime? _tryParseDate(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      plannedError = null;
      washersError = null;
    });

    List<Map<String, dynamic>> nextPlanned = planned;
    List<Map<String, dynamic>> nextWashers = washers;

    String? nextPlannedError;
    String? nextWashersError;

    final plannedFuture = () async {
      try {
        final response = await widget.api.listPlannedShifts(
          widget.session.userId,
          from: _from,
          to: _to,
        );

        final plannedRows = response
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        plannedRows.sort((a, b) {
          final da = _tryParseDate(a['startAt']) ?? DateTime(1970);
          final db = _tryParseDate(b['startAt']) ?? DateTime(1970);
          return da.compareTo(db);
        });

        nextPlanned = plannedRows;
      } catch (e) {
        nextPlannedError = e.toString();
      }
    }();

    final washersFuture = () async {
      try {
        final response = await widget.api.listWashers(widget.session.userId);

        final washerRows = response
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        washerRows.sort((a, b) {
          final an = (a['name'] ?? a['phone'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final bn = (b['name'] ?? b['phone'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return an.compareTo(bn);
        });

        nextWashers = washerRows;
      } catch (e) {
        nextWashersError = e.toString();
      }
    }();

    await Future.wait([plannedFuture, washersFuture]);

    if (!mounted) return;

    setState(() {
      planned = nextPlanned;
      washers = nextWashers;
      plannedError = nextPlannedError;
      washersError = nextWashersError;
      loading = false;
    });
  }

  List<DateTime> _days() {
    final start = _todayOnly(DateTime.now());
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  DateTime get _selectedDay => _days()[selectedDayIndex];

  bool _sameDay(DateTime a, DateTime b) {
    final x = _todayOnly(a);
    final y = _todayOnly(b);
    return x == y;
  }

  bool _isCanceled(Map<String, dynamic> p) {
    final status = (p['status'] ?? '').toString().toUpperCase().trim();
    return status == 'CANCELED';
  }

  List<Map<String, dynamic>> _plannedForDay(DateTime day) {
    final rows = planned.where((p) {
      final start = _tryParseDate(p['startAt']);
      if (start == null) return false;
      if (!_sameDay(start.toLocal(), day)) return false;
      if (!showCanceled && _isCanceled(p)) return false;
      return true;
    }).toList();

    rows.sort((a, b) {
      final da = _tryParseDate(a['startAt']) ?? DateTime(1970);
      final db = _tryParseDate(b['startAt']) ?? DateTime(1970);
      return da.compareTo(db);
    });

    return rows;
  }

  int _totalVisibleShiftsForDay(DateTime day) => _plannedForDay(day).length;

  int _assignedCount(Map<String, dynamic> p) {
    final rows = ((p['washers'] as List?) ?? const []).whereType<Map>().toList();
    return rows.length;
  }

  String _statusText(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'PUBLISHED':
        return 'Опубликована';
      case 'DRAFT':
        return 'Черновик';
      case 'CANCELED':
        return 'Отменена';
      default:
        return raw;
    }
  }

  Color _statusBg(BuildContext context, String raw) {
    final cs = Theme.of(context).colorScheme;
    switch (raw.toUpperCase().trim()) {
      case 'PUBLISHED':
        return cs.secondaryContainer.withValues(alpha: 0.78);
      case 'DRAFT':
        return cs.surfaceContainerHighest.withValues(alpha: 0.78);
      case 'CANCELED':
        return cs.errorContainer.withValues(alpha: 0.78);
      default:
        return cs.surfaceContainerHighest.withValues(alpha: 0.55);
    }
  }

  Color _statusFg(BuildContext context, String raw) {
    final cs = Theme.of(context).colorScheme;
    switch (raw.toUpperCase().trim()) {
      case 'PUBLISHED':
        return cs.onSecondaryContainer;
      case 'DRAFT':
        return cs.onSurface;
      case 'CANCELED':
        return cs.onErrorContainer;
      default:
        return cs.onSurface;
    }
  }

  String _washerTitle(Map<String, dynamic> w) {
    final name = (w['name'] ?? '').toString().trim();
    final phone = (w['phone'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return phone.isEmpty ? 'Мойщик' : phone;
  }

  String _formatShiftTime(Map<String, dynamic> p) {
    final start = _tryParseDate(p['startAt'])?.toLocal();
    final end = _tryParseDate(p['endAt'])?.toLocal();

    if (start == null || end == null) {
      return 'Время не указано';
    }

    final df = DateFormat('HH:mm');
    return '${df.format(start)} — ${df.format(end)}';
  }

  String _formatDayShort(DateTime day) {
    final weekday = DateFormat('EEE', 'ru_RU').format(day);
    final date = DateFormat('dd.MM', 'ru_RU').format(day);
    final w = weekday.isEmpty
        ? ''
        : '${weekday[0].toUpperCase()}${weekday.substring(1)}';
    return '$w • $date';
  }

  String _formatDayLong(DateTime day) {
    final weekday = DateFormat('EEEE', 'ru_RU').format(day);
    final date = DateFormat('d MMMM', 'ru_RU').format(day);
    final w = weekday.isEmpty
        ? ''
        : '${weekday[0].toUpperCase()}${weekday.substring(1)}';
    return '$w • $date';
  }

  Future<void> _createOrEditPlannedShift({
    Map<String, dynamic>? existing,
    DateTime? presetDay,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now().toLocal();

    DateTime startAt;
    DateTime endAt;
    final noteCtrl = TextEditingController();

    if (existing != null) {
      final existingStart = _tryParseDate(existing['startAt'])?.toLocal();
      final existingEnd = _tryParseDate(existing['endAt'])?.toLocal();

      startAt =
          existingStart ?? DateTime(now.year, now.month, now.day, 8, 0);
      endAt = existingEnd ?? startAt.add(const Duration(hours: 12));
      noteCtrl.text = (existing['note'] ?? '').toString();
    } else {
      final base = presetDay ?? now;
      startAt = DateTime(base.year, base.month, base.day, 8, 0);
      endAt = DateTime(base.year, base.month, base.day, 20, 0);
      if (!endAt.isAfter(startAt)) {
        endAt = startAt.add(const Duration(hours: 12));
      }
    }

    Future<void> pickStart(
      BuildContext dialogCtx,
      void Function(void Function()) setD,
    ) async {
      final d = await showDatePicker(
        context: dialogCtx,
        initialDate: startAt,
        firstDate: _todayOnly(DateTime.now()),
        lastDate: _todayOnly(DateTime.now().add(const Duration(days: 60))),
      );
      if (d == null) return;

      final t = await showTimePicker(
        context: dialogCtx,
        initialTime: TimeOfDay.fromDateTime(startAt),
      );
      if (t == null) return;

      startAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (!endAt.isAfter(startAt)) {
        endAt = startAt.add(const Duration(hours: 12));
      }
      setD(() {});
    }

    Future<void> pickEnd(
      BuildContext dialogCtx,
      void Function(void Function()) setD,
    ) async {
      final d = await showDatePicker(
        context: dialogCtx,
        initialDate: endAt,
        firstDate: _todayOnly(DateTime.now()),
        lastDate: _todayOnly(DateTime.now().add(const Duration(days: 60))),
      );
      if (d == null) return;

      final t = await showTimePicker(
        context: dialogCtx,
        initialTime: TimeOfDay.fromDateTime(endAt),
      );
      if (t == null) return;

      endAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (!endAt.isAfter(startAt)) {
        endAt = startAt.add(const Duration(hours: 12));
      }
      setD(() {});
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          final cs = Theme.of(dialogCtx).colorScheme;
          final df = DateFormat('dd.MM HH:mm');

          InputDecoration deco(String label) => InputDecoration(
                labelText: label,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              );

          return AlertDialog(
            title: Text(existing == null ? 'Новая смена' : 'Редактировать смену'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Старт: ${df.format(startAt)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () => pickStart(dialogCtx, setD),
                            child: const Text('Изменить'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Конец: ${df.format(endAt)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () => pickEnd(dialogCtx, setD),
                            child: const Text('Изменить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: deco('Примечание (необязательно)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(existing == null ? 'Создать' : 'Сохранить'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      if (existing == null) {
        await widget.api.createPlannedShift(
          widget.session.userId,
          startAtUtc: startAt.toUtc(),
          endAtUtc: endAt.toUtc(),
          note: noteCtrl.text.trim(),
        );
      } else {
        await widget.api.updatePlannedShift(
          widget.session.userId,
          (existing['id'] ?? '').toString(),
          startAtUtc: startAt.toUtc(),
          endAtUtc: endAt.toUtc(),
          note: noteCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      await load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _assignWasher(Map<String, dynamic> plannedShift) async {
    final messenger = ScaffoldMessenger.of(context);

    if (washersError != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Не удалось загрузить список мойщиков. Обновите экран.'),
        ),
      );
      return;
    }

    final shiftId = (plannedShift['id'] ?? '').toString().trim();
    if (shiftId.isEmpty) return;

    final existingWashers = ((plannedShift['washers'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final assignedWasherIds = existingWashers
        .map((x) => (x['washerId'] ?? '').toString())
        .where((x) => x.isNotEmpty)
        .toSet();

    final availableWashers = washers
        .where((w) => !assignedWasherIds.contains((w['id'] ?? '').toString()))
        .toList();

    if (availableWashers.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Нет доступных мойщиков для назначения.')),
      );
      return;
    }

    String? selectedWasherId =
        (availableWashers.first['id'] ?? '').toString().trim();
    int plannedBayId = 1;
    final noteCtrl = TextEditingController();

    Map<String, dynamic> selectedWasher() {
      return availableWashers.firstWhere(
        (w) => (w['id'] ?? '').toString() == selectedWasherId,
        orElse: () => availableWashers.first,
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          final cs = Theme.of(dialogCtx).colorScheme;

          InputDecoration deco(String label) => InputDecoration(
                labelText: label,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              );

          return AlertDialog(
            title: const Text('Назначить мойщика'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedWasherId,
                  decoration: deco('Мойщик'),
                  items: availableWashers.map((w) {
                    final id = (w['id'] ?? '').toString();
                    final name = _washerTitle(w);
                    final phone = (w['phone'] ?? '').toString().trim();

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        phone.isEmpty ? name : '$name • $phone',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setD(() => selectedWasherId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: plannedBayId,
                  decoration: deco('Пост'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Пост 1')),
                    DropdownMenuItem(value: 2, child: Text('Пост 2')),
                  ],
                  onChanged: (v) => setD(() => plannedBayId = v ?? 1),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: deco('Примечание (необязательно)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Назначить'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      final washer = selectedWasher();
      final phone = (washer['phone'] ?? '').toString().trim();
      if (phone.isEmpty) {
        throw Exception('У выбранного мойщика нет телефона');
      }

      await widget.api.assignWasherToPlannedShift(
        widget.session.userId,
        shiftId,
        washerPhone: phone,
        plannedBayId: plannedBayId,
        note: noteCtrl.text.trim(),
      );

      if (!mounted) return;
      await load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _removeAssignedWasher(
    String plannedShiftId,
    String washerId,
    String washerName,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Снять мойщика?'),
        content: Text('Снять "$washerName" с этой смены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Снять'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.api.unassignWasherFromPlannedShift(
        widget.session.userId,
        plannedShiftId,
        washerId,
      );

      if (!mounted) return;
      await load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _publish(String plannedShiftId) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.api.publishPlannedShift(
        widget.session.userId,
        plannedShiftId,
      );
      if (!mounted) return;
      await load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _deletePlanned(String plannedShiftId) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Удалить смену?'),
        content: const Text(
          'Смена будет отменена и скрыта из рабочего графика.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.api.deletePlannedShift(
        widget.session.userId,
        plannedShiftId,
      );
      if (!mounted) return;
      await load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Widget _headerCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final visibleToday = _plannedForDay(_selectedDay).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
            ),
            child: Icon(Icons.groups_2_outlined, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'График мойщиков',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withValues(alpha: 0.96),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выбран день: ${_formatDayLong(_selectedDay)}',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Смен в показе: $visibleToday',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onErrorContainer,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _createOrEditPlannedShift(
                    presetDay: _selectedDay,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Новая смена'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: loading ? null : load,
                tooltip: 'Обновить',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  selected: showCanceled,
                  label: const Text('Показать отменённые'),
                  onSelected: (v) => setState(() => showCanceled = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayTabs(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = _days();

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = days[i];
          final selected = i == selectedDayIndex;
          final count = _totalVisibleShiftsForDay(day);

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => selectedDayIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.18)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.40)
                      : cs.outlineVariant.withValues(alpha: 0.40),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDayShort(day),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.88),
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.82),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _washersInfoCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final text = washersError != null
        ? 'Не удалось загрузить список мойщиков. Назначение временно отключено.'
        : washers.isEmpty
            ? 'Список мойщиков пуст. Сначала владелец должен добавить мойщиков.'
            : 'Доступно мойщиков: ${washers.length}';

    final icon = washersError != null
        ? Icons.warning_amber_rounded
        : Icons.people_alt_outlined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: washersError != null
            ? cs.errorContainer.withValues(alpha: 0.30)
            : cs.surfaceContainerHighest.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: washersError != null
              ? cs.error.withValues(alpha: 0.25)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: washersError != null ? cs.onErrorContainer : cs.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: washersError != null
                        ? cs.onErrorContainer
                        : cs.onSurface.withValues(alpha: 0.85),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySelectedDay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDayLong(_selectedDay),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            showCanceled
                ? 'Для этого дня нет смен.'
                : 'Для этого дня нет активных или черновых смен.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _createOrEditPlannedShift(presetDay: _selectedDay),
            icon: const Icon(Icons.add),
            label: const Text('Добавить смену'),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String raw) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _statusBg(context, raw),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(raw),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _statusFg(context, raw),
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }

  Widget _assignedWashersBlock(BuildContext context, Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;
    final shiftId = (p['id'] ?? '').toString();

    final rows = ((p['washers'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.40)),
        ),
        child: Text(
          'Мойщики не назначены',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
        ),
      );
    }

    return Column(
      children: rows.map((w) {
        final washer = (w['washer'] is Map)
            ? Map<String, dynamic>.from(w['washer'] as Map)
            : <String, dynamic>{};

        final washerId = (w['washerId'] ?? washer['id'] ?? '').toString();
        final washerTitle = _washerTitle(washer);
        final phone = (washer['phone'] ?? '').toString().trim();
        final bayId = (w['plannedBayId'] as num?)?.toInt();
        final note = (w['note'] ?? '').toString().trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      washerTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            bayId == null ? 'Пост не указан' : 'Пост $bayId',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (note.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Text(
                              note,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Снять мойщика',
                onPressed: washerId.isEmpty
                    ? null
                    : () => _removeAssignedWasher(
                          shiftId,
                          washerId,
                          washerTitle,
                        ),
                icon: const Icon(Icons.person_remove_alt_1),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _plannedCard(BuildContext context, Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;

    final note = (p['note'] ?? '').toString().trim();
    final id = (p['id'] ?? '').toString();
    final status = (p['status'] ?? '').toString();

    final isCanceled = status.toUpperCase().trim() == 'CANCELED';
    final isPublished = status.toUpperCase().trim() == 'PUBLISHED';
    final canAssign = !isCanceled && washersError == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatShiftTime(p),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _statusChip(context, status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.70),
              ),
              const SizedBox(width: 6),
              Text(
                'Назначено: ${_assignedCount(p)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.78),
                    ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.40),
                ),
              ),
              child: Text(
                'Примечание: $note',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _assignedWashersBlock(context, p),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canAssign ? () => _assignWasher(p) : null,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Назначить'),
              ),
              OutlinedButton.icon(
                onPressed:
                    isCanceled ? null : () => _createOrEditPlannedShift(existing: p),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Изменить'),
              ),
              FilledButton.icon(
                onPressed: isCanceled || isPublished ? null : () => _publish(id),
                icon: const Icon(Icons.publish),
                label: const Text('Опубликовать'),
              ),
              TextButton.icon(
                onPressed: isCanceled ? null : () => _deletePlanned(id),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plannedLoadFailedView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.onErrorContainer, size: 34),
              const SizedBox(height: 12),
              Text(
                'Не удалось загрузить график смен.',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onErrorContainer,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                plannedError ?? 'Неизвестная ошибка',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFatalPlannedError = plannedError != null && planned.isEmpty;
    final selectedRows = _plannedForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мойщики'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hasFatalPlannedError
              ? _plannedLoadFailedView(context)
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _headerCard(context),
                      const SizedBox(height: 14),
                      if (plannedError != null) ...[
                        _warningCard(
                          context,
                          icon: Icons.warning_amber_rounded,
                          text:
                              'Не удалось обновить список смен. Показаны последние доступные данные.',
                        ),
                        const SizedBox(height: 12),
                      ],
                      _washersInfoCard(context),
                      const SizedBox(height: 12),
                      _toolbarCard(context),
                      const SizedBox(height: 12),
                      _dayTabs(context),
                      const SizedBox(height: 14),
                      Text(
                        _formatDayLong(_selectedDay),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      if (selectedRows.isEmpty)
                        _emptySelectedDay(context)
                      else
                        ...selectedRows.map(
                          (p) => _plannedCard(context, p),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEditPlannedShift(
          presetDay: _selectedDay,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Смена'),
      ),
    );
  }
}