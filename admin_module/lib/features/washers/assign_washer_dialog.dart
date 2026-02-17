import 'package:flutter/material.dart';

class AssignWasherResult {
  final String washerPhone;
  final int plannedBayId;
  final String? note;

  AssignWasherResult({
    required this.washerPhone,
    required this.plannedBayId,
    this.note,
  });
}

class AssignWasherDialog {
  static Future<AssignWasherResult?> show(
    BuildContext context, {
    String initialPhone = '+7',
    int initialBay = 1,
    String initialNote = '',
  }) async {
    final phoneCtrl = TextEditingController(text: initialPhone);
    final noteCtrl = TextEditingController(text: initialNote);
    int bay = initialBay;

    String? errorText;

    String normalizePhone(String raw) {
      var s = raw.trim();
      if (s.isEmpty) return s;
      s = s.replaceAll(RegExp(r'[^\d\+]'), '');
      if (s.startsWith('8') && s.length == 11) s = '+7${s.substring(1)}';
      if (!s.startsWith('+') && s.startsWith('7') && s.length == 11) s = '+$s';
      return s;
    }

    bool isPhoneOk(String s) {
      final p = normalizePhone(s);
      if (!p.startsWith('+')) return false;
      final digits = p.replaceAll(RegExp(r'\D'), '');
      return digits.length >= 11; // для РФ обычно 11
    }

    final res = await showDialog<AssignWasherResult?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            title: const Text('Приписать мойщика'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Телефон мойщика',
                    errorText: errorText,
                    hintText: '+79990000101',
                  ),
                  onChanged: (_) => setD(() => errorText = null),
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
                  decoration: const InputDecoration(
                    labelText: 'Примечание (опционально)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final phone = normalizePhone(phoneCtrl.text);
                  if (!isPhoneOk(phone)) {
                    setD(() => errorText = 'Проверь телефон');
                    return;
                  }
                  Navigator.of(ctx).pop(
                    AssignWasherResult(
                      washerPhone: phone,
                      plannedBayId: bay,
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    ),
                  );
                },
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      ),
    );

    return res;
  }
}
