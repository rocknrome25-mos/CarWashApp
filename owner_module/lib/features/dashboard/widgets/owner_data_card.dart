import 'package:flutter/material.dart';

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

    Widget child;
    if (snapshot.connectionState == ConnectionState.waiting) {
      child = const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (snapshot.hasError) {
      child = Text(
        'Ошибка загрузки: ${snapshot.error}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFB91C1C),
        ),
      );
    } else if (!snapshot.hasData) {
      child = Text(
        'Нет данных',
        style: theme.textTheme.bodyMedium,
      );
    } else {
      child = childBuilder(snapshot.data!);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}