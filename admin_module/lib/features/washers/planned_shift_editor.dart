import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/admin_api_client.dart';
import '../../core/models/admin_session.dart';

class PlannedShiftEditor {
  static Future<bool> open(
    BuildContext context, {
    required AdminApiClient api,
    required AdminSession session,
    required Map<String, dynamic> plannedShift,
  }) async {
    final id = (plannedShift['id'] ?? '').toString().trim();
    if (id.isEmpty) return false;

    final startIso = (plannedShift['startAt'] ?? '').toString();
    final endIso = (plannedShift['endAt'] ?? '').toString();

    DateTime startAt =
        DateTime.tryParse(startIso)?.toLocal() ?? DateTime.now().toLocal();
    DateTime endAt =
        DateTime.tryParse(endIso)?.toLocal() ??
        startAt.add(const Duration(hours: 12));

    final noteCtrl = TextEditingController(
      text: (plannedShift['note'] ?? '').toString(),
    );

    Future<DateTime?> pickDateTime(
      BuildContext ctx,
      DateTime initial,
      String title,
    ) async {
      final d = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 7)),
        lastDate: DateTime.now().add(const Duration(days: 120)),
        helpText: title,
      );
      if (d == null) return null;

      final t = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: title,
      );
      if (t == null) return null;

      return DateTime(d.year, d.month, d.day, t.hour, t.minute);
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        bool saving = false;
        final df = DateFormat('dd.MM HH:mm');

        Future<void> save(StateSetter setS) async {
          if (saving) return;
          setS(() => saving = true);

          try {
            await api.updatePlannedShift(
              session.userId,
              id,
              startAtUtc: startAt.toUtc(),
              endAtUtc: endAt.toUtc(),
              note: noteCtrl.text.trim(), // можно пустое — очистит
            );
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop(true);
          } catch (e) {
            if (!sheetCtx.mounted) return;
            ScaffoldMessenger.of(
              sheetCtx,
            ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
          } finally {
            if (sheetCtx.mounted) setS(() => saving = false);
          }
        }

        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setS) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Редактировать смену',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await pickDateTime(
                                ctx,
                                startAt,
                                'Старт',
                              );
                              if (picked == null) return;
                              setS(() {
                                startAt = picked;
                                if (endAt.isBefore(startAt)) {
                                  endAt = startAt.add(
                                    const Duration(hours: 12),
                                  );
                                }
                              });
                            },
                      icon: const Icon(Icons.schedule),
                      label: Text('Старт: ${df.format(startAt)}'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await pickDateTime(
                                ctx,
                                endAt,
                                'Конец',
                              );
                              if (picked == null) return;
                              setS(() {
                                endAt = picked;
                                if (endAt.isBefore(startAt)) {
                                  endAt = startAt.add(
                                    const Duration(hours: 12),
                                  );
                                }
                              });
                            },
                      icon: const Icon(Icons.schedule),
                      label: Text('Конец: ${df.format(endAt)}'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Примечание',
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: saving ? null : () => save(setS),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.done),
                        label: Text(saving ? 'Сохраняю...' : 'Сохранить'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return changed == true;
  }
}
