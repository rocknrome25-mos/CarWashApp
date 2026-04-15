import 'package:flutter/material.dart';

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
    return SegmentedButton<OwnerSummaryPeriod>(
      segments: const [
        ButtonSegment<OwnerSummaryPeriod>(
          value: OwnerSummaryPeriod.day,
          label: Text('День'),
        ),
        ButtonSegment<OwnerSummaryPeriod>(
          value: OwnerSummaryPeriod.month,
          label: Text('Месяц'),
        ),
        ButtonSegment<OwnerSummaryPeriod>(
          value: OwnerSummaryPeriod.year,
          label: Text('Год'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }
}
