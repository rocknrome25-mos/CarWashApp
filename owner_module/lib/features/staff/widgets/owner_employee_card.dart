import 'package:flutter/material.dart';

class OwnerEmployeeCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const OwnerEmployeeCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = (data['name'] ?? 'Без имени').toString();
    final phone = (data['phone'] ?? '').toString();
    final role = (data['role'] ?? '').toString();
    final isActive = data['isActive'] == true;
    final mustChangePassword = data['mustChangePassword'] == true;

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
                  if (mustChangePassword) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Нужно сменить пароль при входе',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          ],
        ),
      ),
    );
  }
}