import 'package:flutter/material.dart';

import '../../../core/api/owner_api_client.dart';

class OwnerTopBrandBlock extends StatelessWidget {
  const OwnerTopBrandBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final api = OwnerApiClient();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFFFEEE8),
              child: Icon(
                Icons.blur_circular,
                color: Colors.deepOrange.shade400,
                size: 26,
              ),
            ),
            Positioned(
              right: -1,
              top: -1,
              child: FutureBuilder<Map<String, dynamic>>(
                future: api.getHealth(),
                builder: (context, snapshot) {
                  final status = snapshot.data?['status'];

                  Color color;
                  if (status == 'ok') {
                    color = const Color(0xFF16A34A);
                  } else if (status == 'warning') {
                    color = const Color(0xFFF59E0B);
                  } else {
                    color = const Color(0xFFDC2626);
                  }

                  return Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ЖК Рассказово',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'г. Москва, бульвар Андрея Тарковского, д. 10',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
