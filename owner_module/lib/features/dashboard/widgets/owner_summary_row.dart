import 'package:flutter/material.dart';

class OwnerSummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const OwnerSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}