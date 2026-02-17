import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';
import 'assign_washer_dialog.dart';
import 'planned_shift_editor.dart';

class PlannedShiftTile extends StatelessWidget {
  final AdminApiClient api;
  final AdminSession session;

  final Map<String, dynamic> plannedShift;
  final VoidCallback onChanged; // перезагрузить список

  const PlannedShiftTile({
    super.key,
    required this.api,
    required this.session,
    required this.plannedShift,
    required this.onChanged,
  });

  String _status(String raw) => raw.toUpperCase().trim();

  List<Map<String, dynamic>> _assignments() {
    final raw = plannedShift['assignments'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    // иногда могут вернуть washerAssignments или plannedAssignments
    final raw2 = plannedShift['washerAssignments'];
    if (raw2 is List) {
      return raw2
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  int? _plannedBayIdOf(Map<String, dynamic> a) {
    final v = a['plannedBayId'] ?? a['bayId'];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  Map<String, dynamic>? _washerOf(Map<String, dynamic> a) {
    final w = a['washer'];
    if (w is Map) return w.cast<String, dynamic>();
    return null;
  }

  Future<void> _assign(BuildContext context) async {
    final id = (plannedShift['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final res = await AssignWasherDialog.show(context);
    if (res == null) return;

    try {
      await api.assignWasherToPlannedShift(
        session.userId,
        id,
        washerPhone: res.washerPhone,
        plannedBayId: res.plannedBayId,
        note: res.note,
      );
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _publish(BuildContext context) async {
    final id = (plannedShift['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    try {
      await api.publishPlannedShift(session.userId, id);
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final id = (plannedShift['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить смену?'),
        content: const Text('Плановая смена будет удалена из графика.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api.deletePlannedShift(session.userId, id);
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await PlannedShiftEditor.open(
      context,
      api: api,
      session: session,
      plannedShift: plannedShift,
    );
    if (changed) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final startIso = (plannedShift['startAt'] ?? '').toString();
    final endIso = (plannedShift['endAt'] ?? '').toString();
    final start = DateTime.tryParse(startIso)?.toLocal();
    final end = DateTime.tryParse(endIso)?.toLocal();

    final note = (plannedShift['note'] ?? '').toString().trim();
    final status = _status((plannedShift['status'] ?? '').toString());

    final df = DateFormat('dd.MM HH:mm');
    final title = (start != null && end != null)
        ? '${df.format(start)} — ${df.format(end)}'
        : 'Смена';

    // assignments grouped by plannedBayId
    final asg = _assignments();
    asg.sort((a, b) {
      final ba = _plannedBayIdOf(a) ?? 99;
      final bb = _plannedBayIdOf(b) ?? 99;
      if (ba != bb) return ba.compareTo(bb);
      return (a['createdAt'] ?? '').toString().compareTo(
        (b['createdAt'] ?? '').toString(),
      );
    });

    Widget statusChip() {
      IconData icon;
      String label;
      Color bg;
      Color fg;

      switch (status) {
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
          label = status.isEmpty ? '—' : status;
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

    Widget assignmentRow(Map<String, dynamic> a) {
      final bay = _plannedBayIdOf(a);
      final w = _washerOf(a);
      final phone = (w?['phone'] ?? '').toString().trim();
      final name = (w?['name'] ?? '').toString().trim();

      final bayLabel = bay == null ? 'Пост —' : 'Пост $bay';
      final who = name.isNotEmpty ? name : (phone.isNotEmpty ? phone : '—');

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.local_car_wash, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bayLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    who,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (phone.isNotEmpty && name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
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
              statusChip(),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Примечание: $note',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.75),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),

          if (asg.isEmpty)
            Text(
              'Пока нет приписанных мойщиков.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            for (final a in asg) ...[
              assignmentRow(a),
              const SizedBox(height: 10),
            ],
          ],

          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _assign(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Приписать'),
              ),
              OutlinedButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Правка'),
              ),
              OutlinedButton.icon(
                onPressed: status == 'PUBLISHED'
                    ? null
                    : () => _publish(context),
                icon: const Icon(Icons.publish),
                label: const Text('Опубликовать'),
              ),
              TextButton.icon(
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
