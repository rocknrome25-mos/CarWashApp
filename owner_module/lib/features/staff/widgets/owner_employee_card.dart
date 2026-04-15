import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class OwnerEmployeeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onUpdated;

  const OwnerEmployeeCard({
    super.key,
    required this.data,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final id = (data['id'] ?? '').toString();
    final name = (data['name'] ?? 'Без имени').toString();
    final phone = (data['phone'] ?? '').toString();
    final role = (data['role'] ?? '').toString();
    final isActive = data['isActive'] == true;
    final mustChangePassword = data['mustChangePassword'] == true;
    final lastLoginAt = data['lastLoginAt'];

    final roleLabel = role == 'ADMIN' ? 'Администратор' : 'Мойщик';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFF3F4F6),
              child: Icon(
                role == 'ADMIN'
                    ? Icons.badge_outlined
                    : Icons.cleaning_services_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (phone.isNotEmpty)
                    Text(phone, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    roleLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mustChangePassword)
                    _statusChip('Требуется смена пароля', Colors.orange),
                  if (lastLoginAt != null)
                    _statusChip(
                      'Вход: ${_formatDate(lastLoginAt.toString())}',
                      Colors.blueGrey,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Активен' : 'Отключён',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _edit(context, id, name, phone);
                    } else if (value == 'toggle') {
                      _toggle(context, id);
                    } else if (value == 'reset') {
                      _resetPassword(context, id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Редактировать'),
                    ),
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Text(isActive ? 'Отключить' : 'Активировать'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'reset',
                      child: Text('Сбросить пароль'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;

    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  Future<void> _toggle(BuildContext context, String id) async {
    final uri = Uri.parse(
      '${AppConfig.defaultBaseUrl}/owner/employees/$id/toggle',
    );

    final response = await http.post(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось изменить статус сотрудника');
    }

    onUpdated();
  }

  Future<void> _resetPassword(BuildContext context, String id) async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новый пароль'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Пароль'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final uri = Uri.parse(
      '${AppConfig.defaultBaseUrl}/owner/employees/$id/reset-password',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': controller.text.trim()}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось сбросить пароль');
    }

    onUpdated();
  }

  Future<void> _edit(
    BuildContext context,
    String id,
    String currentName,
    String currentPhone,
  ) async {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактировать'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final uri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/employees/$id');

    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось сохранить изменения');
    }

    onUpdated();
  }
}
