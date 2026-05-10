import 'package:flutter/material.dart';

import '../../../core/api/owner_api_client.dart';
import '../../../core/theme/app_theme.dart';

class OwnerTopBrandBlock extends StatelessWidget {
  const OwnerTopBrandBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final api = OwnerApiClient();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      decoration: BoxDecoration(
        color: cs.bg2, // Основная карточка header

        borderRadius: BorderRadius.circular(22),

        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),

        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.03),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Логотип / статус
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  ),

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
                ),

                child: Icon(
                  Icons.blur_circular_rounded,
                  color: cs.primary,
                  size: 28,
                ),
              ),

              Positioned(
                right: -2,
                top: -2,
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

                        border: Border.all(color: cs.bg2, width: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Информация о мойке
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

                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'г. Москва, бульвар Андрея Тарковского, д. 10',

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
