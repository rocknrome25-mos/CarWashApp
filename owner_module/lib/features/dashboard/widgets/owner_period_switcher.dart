import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum OwnerSummaryPeriod { day, month, year }

extension OwnerSummaryPeriodApiValue on OwnerSummaryPeriod {
  String get apiValue {
    switch (this) {
      case OwnerSummaryPeriod.day:
        return 'day';
      case OwnerSummaryPeriod.month:
        return 'month';
      case OwnerSummaryPeriod.year:
        return 'year';
    }
  }

  String get label {
    switch (this) {
      case OwnerSummaryPeriod.day:
        return 'День';
      case OwnerSummaryPeriod.month:
        return 'Месяц';
      case OwnerSummaryPeriod.year:
        return 'Год';
    }
  }
}

class OwnerPeriodSwitcher extends StatelessWidget {
  final OwnerSummaryPeriod value;
  final ValueChanged<OwnerSummaryPeriod> onChanged;

  const OwnerPeriodSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final periods = OwnerSummaryPeriod.values;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.bg3, // Фон переключателя
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          for (final period in periods)
            Expanded(
              child: _PeriodButton(
                label: period.label,
                selected: value == period,
                onTap: () => onChanged(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: selected ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? cs.bg2 : Colors.transparent, // Активный фон
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.24)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? cs.primary : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
