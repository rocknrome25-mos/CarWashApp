import 'package:flutter/material.dart';

import '../../core/api/owner_api_client.dart';

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ошибка загрузки: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
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
                        color: const Color(0xFF6B7280),
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

    final title = (alert['title'] ?? 'Уведомление').toString();
    final message = (alert['message'] ?? '').toString();
    final severity = (alert['severity'] ?? '').toString();
    final type = (alert['type'] ?? '').toString();
    final createdAt = _formatDateTime((alert['createdAt'] ?? '').toString());
    final isRead = alert['isRead'] == true;

    final severityData = _severityData(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: severityData.color, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(severityData.icon, color: severityData.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  if (!isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Новое',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (message.trim().isNotEmpty)
                Text(message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallChip(text: severityData.label),
                  if (type.trim().isNotEmpty)
                    _SmallChip(text: _typeLabel(type)),
                  if (createdAt.trim().isNotEmpty) _SmallChip(text: createdAt),
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

  const _SmallChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
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
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
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
