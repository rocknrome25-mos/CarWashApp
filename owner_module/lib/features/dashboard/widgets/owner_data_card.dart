import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class OwnerDataCard extends StatelessWidget {
  final String title;
  final AsyncSnapshot<Map<String, dynamic>> snapshot;
  final Widget Function(Map<String, dynamic> data) childBuilder;

  const OwnerDataCard({
    super.key,
    required this.title,
    required this.snapshot,
    required this.childBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget child;

    if (snapshot.connectionState == ConnectionState.waiting) {
      child = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: cs.bg3, // Внутренний фон
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    } else if (snapshot.hasError) {
      child = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.36), // Фон ошибки
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.error.withValues(alpha: 0.35)),
        ),
        child: Text(
          'Ошибка загрузки: ${snapshot.error}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (!snapshot.hasData) {
      child = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.bg3, // Внутренний фон
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: Text(
          'Нет данных',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      child = childBuilder(snapshot.data!);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.bg2, // Основная карточка
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withValues(alpha: 0.035),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;

  const _CardHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: cs.primary, // Accent линия
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
