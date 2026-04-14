import 'package:flutter/material.dart';

class OwnerPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;

  const OwnerPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          child ??
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Раздел в работе',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}