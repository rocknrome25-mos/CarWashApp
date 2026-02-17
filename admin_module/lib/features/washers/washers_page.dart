// C:\dev\carwash\admin_module\lib\features\washers\washers_page.dart
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
  String? error;

  List<Map<String, dynamic>> planned = [];

  DateTime get _from => DateTime.now();
  DateTime get _to => DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    load();
  }

  // ✅ Normalize phone so backend can find washer by `phone` exactly
  String _normalizePhoneForDb(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    // keep only + and digits
    s = s.replaceAll(RegExp(r'[^\d\+]'), '');

    // 8XXXXXXXXXX -> +7XXXXXXXXXX
    if (s.startsWith('8') && s.length == 11) {
      s = '+7${s.substring(1)}';
    }

    // 7XXXXXXXXXX -> +7XXXXXXXXXX
    if (!s.startsWith('+') && s.startsWith('7') && s.length == 11) {
      s = '+$s';
    }

    return s;
  }

  Future<void> load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final rows = await widget.api.listPlannedShifts(
        widget.session.userId,
        from: _from,
        to: _to,
      );

      final list = rows
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      list.sort((a, b) {
        final da =
            DateTime.tryParse((a['startAt'] ?? '').toString()) ?? DateTime(1970);
        final db =
            DateTime.tryParse((b['startAt'] ?? '').toString()) ?? DateTime(1970);
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() => planned = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _createPlannedShift() async {
    final messenger = ScaffoldMessenger.of(context);

    final now = DateTime.now().toLocal();
    final startDefault =
        DateTime(now.year, now.month, now.day, 8, 0).add(const Duration(days: 1));
    final endDefault =
        DateTime(now.year, now.month, now.day, 20, 0).add(const Duration(days: 1));

    DateTime startAt = startDefault;
    DateTime endAt = endDefault;
    final noteCtrl = TextEditingController(text: 'Дневная смена');

    Future<void> pickStart(BuildContext dialogCtx, void Function(void Function()) setD) async {
      final d = await showDatePicker(
        context: dialogCtx,
        initialDate: startAt,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 60)),
      );
      if (d == null) return;

      final t = await showTimePicker(
        context: dialogCtx,
        initialTime: TimeOfDay.fromDateTime(startAt),
      );
      if (t == null) return;

      startAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (endAt.isBefore(startAt)) {
        endAt = startAt.add(const Duration(hours: 12));
      }
      setD(() {});
    }

    Future<void> pickEnd(BuildContext dialogCtx, void Function(void Function()) setD) async {
      final d = await showDatePicker(
        context: dialogCtx,
        initialDate: endAt,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 60)),
      );
      if (d == null) return;

      final t = await showTimePicker(
        context: dialogCtx,
        initialTime: TimeOfDay.fromDateTime(endAt),
      );
      if (t == null) return;

      endAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (endAt.isBefore(startAt)) {
        endAt = startAt.add(const Duration(hours: 12));
      }
      setD(() {});
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setD) {
          final df = DateFormat('dd.MM HH:mm');
          return AlertDialog(
            title: const Text('Новая смена'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Старт: ${df.format(startAt)}')),
                    TextButton(
                      onPressed: () => pickStart(dialogCtx, setD),
                      child: const Text('Изменить'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Конец: ${df.format(endAt)}')),
                    TextButton(
                      onPressed: () => pickEnd(dialogCtx, setD),
                      child: const Text('Изменить'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Примечание (необязательно)',
                  ),
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
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      await widget.api.createPlannedShift(
        widget.session.userId,
        startAtUtc: startAt.toUtc(),
        endAtUtc: endAt.toUtc(),
        note: noteCtrl.text.trim(),
      );

      if (!mounted) return;
      await load();
    } catch (e) {
      // no context use after await; messenger is captured before
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _assignWasher(String plannedShiftId) async {
    final messenger = ScaffoldMessenger.of(context);

    final phoneCtrl = TextEditingController(text: '+7999');
    int bay = 1;
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setD) => AlertDialog(
          title: const Text('Приписать мойщика'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Телефон мойщика'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: bay,
                decoration: const InputDecoration(labelText: 'Пост'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Пост 1')),
                  DropdownMenuItem(value: 2, child: Text('Пост 2')),
                ],
                onChanged: (v) => setD(() => bay = v ?? 1),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Примечание (опц.)'),
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
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await widget.api.assignWasherToPlannedShift(
        widget.session.userId,
        plannedShiftId,
        washerPhone: _normalizePhoneForDb(phoneCtrl.text),
        plannedBayId: bay,
        note: noteCtrl.text.trim(),
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
      await widget.api.publishPlannedShift(widget.session.userId, plannedShiftId);
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
        content: const Text('Это удалит плановую смену из графика.'),
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
      await widget.api.deletePlannedShift(widget.session.userId, plannedShiftId);
      if (!mounted) return;
      await load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('dd.MM HH:mm');

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlannedShift,
        icon: const Icon(Icons.add),
        label: const Text('Смена'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error!),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.calendar_month, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'График на неделю',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Создавай смены и приписывай мойщиков по постам.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: cs.onSurface.withValues(alpha: 0.70),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (planned.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                color: cs.onSurface.withValues(alpha: 0.65),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Пока нет плановых смен на ближайшую неделю.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface.withValues(alpha: 0.75),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      for (final p in planned) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${df.format(DateTime.parse((p['startAt'] ?? '').toString()).toLocal())}'
                                      ' — ${df.format(DateTime.parse((p['endAt'] ?? '').toString()).toLocal())}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  _StatusChip(status: (p['status'] ?? '').toString()),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if ((p['note'] ?? '').toString().trim().isNotEmpty)
                                Text(
                                  'Примечание: ${(p['note'] ?? '').toString().trim()}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurface.withValues(alpha: 0.75),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _assignWasher((p['id'] ?? '').toString()),
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: const Text('Приписать'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _publish((p['id'] ?? '').toString()),
                                    icon: const Icon(Icons.publish),
                                    label: const Text('Опубликовать'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _deletePlanned((p['id'] ?? '').toString()),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Удалить'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = status.toUpperCase().trim();

    IconData icon;
    String label;
    Color bg;
    Color fg;

    switch (s) {
      case 'PUBLISHED':
        icon = Icons.verified;
        label = 'Опублик.';
        bg = cs.secondaryContainer.withValues(alpha: 0.7);
        fg = cs.onSecondaryContainer;
        break;
      case 'DRAFT':
        icon = Icons.edit_note;
        label = 'Черновик';
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.55);
        fg = cs.onSurface;
        break;
      case 'CANCELED':
        icon = Icons.cancel;
        label = 'Отменено';
        bg = cs.errorContainer.withValues(alpha: 0.7);
        fg = cs.onErrorContainer;
        break;
      default:
        icon = Icons.help_outline;
        label = s.isEmpty ? '—' : s;
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.45);
        fg = cs.onSurface;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
