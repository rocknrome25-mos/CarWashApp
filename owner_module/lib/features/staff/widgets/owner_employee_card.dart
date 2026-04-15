import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerEmployeeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onToggle;

  const OwnerEmployeeCard({super.key, required this.data, this.onToggle});

  String _formatDateTime(dynamic value) {
    if (value == null) return 'Не входил';
    final raw = value.toString();
    if (raw.isEmpty) return 'Не входил';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    return DateFormat('dd.MM.yyyy HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = (data['name'] ?? 'Без имени').toString();
    final phone = (data['phone'] ?? '').toString();
    final role = (data['role'] ?? '').toString();
    final isActive = data['isActive'] == true;
    final mustChangePassword = data['mustChangePassword'] == true;
    final lastLoginAt = _formatDateTime(data['lastLoginAt']);

    final roleLabel = role == 'ADMIN' ? 'Администратор' : 'Мойщик';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
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
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                    IconButton(
                      tooltip: isActive ? 'Отключить' : 'Активировать',
                      onPressed: onToggle,
                      icon: Icon(
                        isActive ? Icons.toggle_on : Icons.toggle_off,
                        size: 34,
                        color: isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(
                    label: 'Смена пароля',
                    value: mustChangePassword ? 'Требуется' : 'Не требуется',
                    valueColor: mustChangePassword
                        ? const Color(0xFF9A3412)
                        : const Color(0xFF166534),
                  ),
                  const SizedBox(height: 8),
                  _MetaRow(label: 'Последний вход', value: lastLoginAt),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetaRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
