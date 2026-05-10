import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class OwnerInfoTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const OwnerInfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: cs.bg3, // Внутренний surface

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),

        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.02),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Text(
            title,

            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
            ),
          ),

          const SizedBox(height: 14),

          // Основное значение
          Text(
            value,

            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 8),

          // Подпись
          Text(
            subtitle,

            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
