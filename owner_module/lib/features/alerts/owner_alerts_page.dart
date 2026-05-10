import 'package:flutter/material.dart';

import '../../core/api/owner_api_client.dart';
import '../../core/theme/app_theme.dart';

class OwnerAlertsPage extends StatefulWidget {
  const OwnerAlertsPage({super.key});

  @override
  State<OwnerAlertsPage> createState() => _OwnerAlertsPageState();
}

class _OwnerAlertsPageState extends State<OwnerAlertsPage> {
  final OwnerApiClient _api = OwnerApiClient();

  late Future<Map<String, dynamic>> _future;
  bool _unreadOnly = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
    return _api.getOwnerAlerts(
      period: 'month',
      unreadOnly: _unreadOnly,
      limit: 100,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });

    await _future;
  }

  Future<void> _markRead(String id) async {
    if (_isBusy || id.trim().isEmpty) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await _api.markOwnerAlertRead(id);
      await _reload();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Уведомление отмечено прочитанным')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления владельца'),
        actions: [
          TextButton.icon(
            onPressed: _isBusy ? null : _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.bg2, // Карточка ошибки
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: cs.error.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: cs.error, size: 34),
                          const SizedBox(height: 12),
                          Text(
                            'Ошибка загрузки: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final data = snapshot.data ?? const <String, dynamic>{};
              final totals = Map<String, dynamic>.from(
                (data['totals'] as Map?) ?? const {},
              );

              final total = _asInt(totals['total']);
              final unreadTotal = _asInt(totals['unreadTotal']);
              final criticalUnreadTotal = _asInt(totals['criticalUnreadTotal']);

              final alerts = ((data['alerts'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Уведомления',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        FilterChip(
                          label: const Text('Только непрочитанные'),
                          selected: _unreadOnly,
                          onSelected: (value) {
                            setState(() {
                              _unreadOnly = value;
                              _future = _load();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Критические события, кассовые расхождения и важные действия администраторов.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            title: 'Всего',
                            value: '$total',
                            subtitle: 'За текущий месяц',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            title: 'Непрочитанные',
                            value: '$unreadTotal',
                            subtitle: 'Критических: $criticalUnreadTotal',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (alerts.isEmpty)
                      const _EmptyBlock(text: 'Уведомлений пока нет')
                    else
                      ...alerts.map(
                        (alert) => _AlertCard(
                          alert: alert,
                          onMarkRead: () {
                            final id = (alert['id'] ?? '').toString();
                            _markRead(id);
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_isBusy)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onMarkRead;

  const _AlertCard({required this.alert, required this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = (alert['title'] ?? 'Уведомление').toString();
    final message = (alert['message'] ?? '').toString();
    final severity = (alert['severity'] ?? '').toString();
    final type = (alert['type'] ?? '').toString();
    final createdAt = _formatDateTime((alert['createdAt'] ?? '').toString());
    final isRead = alert['isRead'] == true;

    final severityData = _severityData(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.bg2, // Карточка уведомления
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.025),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              color: severityData.color, // Линия важности
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: severityData.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            severityData.icon,
                            color: severityData.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Новое',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (message.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallChip(
                          text: severityData.label,
                          color: severityData.color,
                        ),
                        if (type.trim().isNotEmpty)
                          _SmallChip(text: _typeLabel(type)),
                        if (createdAt.trim().isNotEmpty)
                          _SmallChip(text: createdAt),
                      ],
                    ),
                    if (!isRead) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: onMarkRead,
                          icon: const Icon(Icons.done),
                          label: const Text('Прочитано'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _SeverityData _severityData(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return const _SeverityData(
          label: 'Критично',
          color: Color(0xFFDC2626),
          icon: Icons.warning_amber_rounded,
        );
      case 'WARNING':
        return const _SeverityData(
          label: 'Важно',
          color: Color(0xFFF59E0B),
          icon: Icons.error_outline,
        );
      case 'INFO':
      default:
        return const _SeverityData(
          label: 'Информация',
          color: Color(0xFF2563EB),
          icon: Icons.info_outline,
        );
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'CASH_MISMATCH':
        return 'Расхождение кассы';
      case 'BOOKING_DISCOUNT':
        return 'Скидка';
      case 'BOOKING_DELETE':
        return 'Отмена бронирования';
      case 'WAITLIST_DELETE':
        return 'Отмена waitlist';
      case 'BAY_CLOSE':
        return 'Закрытие поста';
      case 'BAY_OPEN':
        return 'Открытие поста';
      default:
        return type;
    }
  }
}

class _SeverityData {
  final String label;
  final Color color;
  final IconData icon;

  const _SeverityData({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _SmallChip extends StatelessWidget {
  final String text;
  final Color? color;

  const _SmallChip({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.10), // Фон chip
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: effectiveColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _MetricTile({
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
        color: cs.bg3, // Метрика
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final String text;

  const _EmptyBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.bg2, // Пустое состояние
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.60)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _formatDateTime(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;

  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}
