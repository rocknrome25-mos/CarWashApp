import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/owner_api_client.dart';
import '../../core/data/app_repository.dart';
import '../alerts/owner_alerts_page.dart';
import '../clients/owner_clients_tab.dart';
import '../dashboard/owner_dashboard_tab.dart';
import '../services/owner_services_tab.dart';
import '../settings/owner_settings_tab.dart';
import '../staff/owner_employees_tab.dart';
import 'widgets/owner_top_brand_block.dart';

class OwnerShellPage extends StatefulWidget {
  final AppRepository repo;
  final VoidCallback onLogout;

  const OwnerShellPage({super.key, required this.repo, required this.onLogout});

  @override
  State<OwnerShellPage> createState() => _OwnerShellPageState();
}

class _OwnerShellPageState extends State<OwnerShellPage> {
  final OwnerApiClient _api = OwnerApiClient();

  int _index = 0;
  Timer? _alertsTimer;

  bool _loadingAlerts = false;
  int _unreadAlerts = 0;
  int _criticalUnreadAlerts = 0;
  List<Map<String, dynamic>> _latestAlerts = [];

  final Set<String> _shownCriticalAlertIds = {};

  @override
  void initState() {
    super.initState();

    _loadAlerts(showCriticalPopup: true);

    _alertsTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadAlerts(showCriticalPopup: true),
    );
  }

  @override
  void dispose() {
    _alertsTimer?.cancel();
    super.dispose();
  }

  void _logout() {
    widget.onLogout();
  }

  void _openSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Связь с техподдержкой подключим следующим этапом'),
      ),
    );
  }

  Future<void> _loadAlerts({required bool showCriticalPopup}) async {
    if (_loadingAlerts) return;

    _loadingAlerts = true;

    try {
      final data = await _api.getOwnerAlerts(
        period: 'month',
        unreadOnly: false,
        limit: 20,
      );

      final totals = Map<String, dynamic>.from(
        (data['totals'] as Map?) ?? const {},
      );

      final unread = _asInt(totals['unreadTotal']);
      final criticalUnread = _asInt(totals['criticalUnreadTotal']);

      final alerts = ((data['alerts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;

      setState(() {
        _unreadAlerts = unread;
        _criticalUnreadAlerts = criticalUnread;
        _latestAlerts = alerts.take(8).toList();
      });

      if (showCriticalPopup) {
        final critical = alerts.where((alert) {
          final id = (alert['id'] ?? '').toString();
          final severity = (alert['severity'] ?? '').toString();
          final isRead = alert['isRead'] == true;

          return id.isNotEmpty &&
              severity == 'CRITICAL' &&
              !isRead &&
              !_shownCriticalAlertIds.contains(id);
        }).toList();

        if (critical.isNotEmpty) {
          final first = critical.first;
          final id = (first['id'] ?? '').toString();

          _shownCriticalAlertIds.add(id);

          if (!mounted) return;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showCriticalAlertDialog(first);
            }
          });
        }
      }
    } catch (_) {
      // Не ломаем owner-кабинет, если alerts временно недоступны.
    } finally {
      _loadingAlerts = false;
    }
  }

  Future<void> _showCriticalAlertDialog(Map<String, dynamic> alert) async {
    final id = (alert['id'] ?? '').toString();
    final title = (alert['title'] ?? 'Критическое уведомление').toString();
    final message = (alert['message'] ?? '').toString();
    final createdAt = _formatDateTime((alert['createdAt'] ?? '').toString());

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.trim().isNotEmpty) Text(message),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  createdAt,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('details'),
            child: const Text('Открыть список'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('read'),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == 'read' && id.isNotEmpty) {
      try {
        await _api.markOwnerAlertRead(id);
        await _loadAlerts(showCriticalPopup: false);
      } catch (_) {
        // Игнорируем ошибку чтения уведомления.
      }
    }

    if (result == 'details') {
      await _openAlertsPage();
    }
  }

  Future<void> _openAlertsPreview() async {
    await _loadAlerts(showCriticalPopup: false);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _AlertsPreviewDialog(
        alerts: _latestAlerts,
        unreadCount: _unreadAlerts,
        criticalUnreadCount: _criticalUnreadAlerts,
        onOpenAll: () {
          Navigator.of(context).pop();
          _openAlertsPage();
        },
      ),
    );

    if (!mounted) return;
    await _loadAlerts(showCriticalPopup: false);
  }

  Future<void> _openAlertsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const OwnerAlertsPage()));

    if (!mounted) return;

    await _loadAlerts(showCriticalPopup: false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OwnerDashboardTab(),
      const OwnerEmployeesTab(),
      const OwnerClientsTab(),
      const OwnerServicesTab(),
      const OwnerSettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 96,
        titleSpacing: 12,
        title: const OwnerTopBrandBlock(),
        actions: [
          _AlertBellButton(
            unreadCount: _unreadAlerts,
            criticalUnreadCount: _criticalUnreadAlerts,
            onPressed: _openAlertsPreview,
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _openSupport,
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Помощь'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Выход'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Сводка',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Сотрудники',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Клиенты',
          ),
          NavigationDestination(
            icon: Icon(Icons.miscellaneous_services_outlined),
            selectedIcon: Icon(Icons.miscellaneous_services),
            label: 'Сервисы',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
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

class _AlertBellButton extends StatelessWidget {
  final int unreadCount;
  final int criticalUnreadCount;
  final VoidCallback onPressed;

  const _AlertBellButton({
    required this.unreadCount,
    required this.criticalUnreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final hasCritical = criticalUnreadCount > 0;

    return IconButton(
      tooltip: hasUnread ? 'Уведомления: $unreadCount' : 'Уведомления',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            hasUnread
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
          ),
          if (hasUnread)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: hasCritical
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertsPreviewDialog extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final int unreadCount;
  final int criticalUnreadCount;
  final VoidCallback onOpenAll;

  const _AlertsPreviewDialog({
    required this.alerts,
    required this.unreadCount,
    required this.criticalUnreadCount,
    required this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          const Icon(Icons.notifications_active_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Уведомления', style: theme.textTheme.titleLarge),
          ),
          if (unreadCount > 0)
            _AlertCounterPill(
              text: '$unreadCount новых',
              color: criticalUnreadCount > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFF59E0B),
            ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: alerts.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Новых уведомлений нет'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  ...alerts.take(6).map((alert) {
                    return _AlertPreviewCard(alert: alert);
                  }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
        FilledButton.icon(
          onPressed: onOpenAll,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Открыть все'),
        ),
      ],
    );
  }
}

class _AlertPreviewCard extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _AlertPreviewCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = (alert['title'] ?? 'Уведомление').toString();
    final message = (alert['message'] ?? '').toString().trim();
    final severity = (alert['severity'] ?? '').toString().toUpperCase();
    final type = (alert['type'] ?? alert['eventType'] ?? '').toString();
    final isRead = alert['isRead'] == true;
    final createdAt = _formatDateTime((alert['createdAt'] ?? '').toString());

    final ui = _alertSeverityUi(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF8FAFC) : ui.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ui.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ui.iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ui.icon, color: ui.iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4B5563),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniMetaPill(text: ui.label),
                    if (type.trim().isNotEmpty) _MiniMetaPill(text: type),
                    if (createdAt.trim().isNotEmpty)
                      _MiniMetaPill(text: createdAt),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCounterPill extends StatelessWidget {
  final String text;
  final Color color;

  const _AlertCounterPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniMetaPill extends StatelessWidget {
  final String text;

  const _MiniMetaPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }
}

class _AlertSeverityUi {
  final String label;
  final IconData icon;
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color iconColor;

  const _AlertSeverityUi({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.iconColor,
  });
}

_AlertSeverityUi _alertSeverityUi(String severity) {
  switch (severity) {
    case 'CRITICAL':
      return const _AlertSeverityUi(
        label: 'Критично',
        icon: Icons.priority_high_rounded,
        background: Color(0xFFFFF1F2),
        border: Color(0xFFFCA5A5),
        iconBackground: Color(0xFFFEE2E2),
        iconColor: Color(0xFFDC2626),
      );
    case 'WARNING':
    case 'WARN':
      return const _AlertSeverityUi(
        label: 'Внимание',
        icon: Icons.warning_amber_rounded,
        background: Color(0xFFFFFBEB),
        border: Color(0xFFFCD34D),
        iconBackground: Color(0xFFFEF3C7),
        iconColor: Color(0xFFD97706),
      );
    case 'INFO':
    default:
      return const _AlertSeverityUi(
        label: 'Инфо',
        icon: Icons.info_outline_rounded,
        background: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
        iconBackground: Color(0xFFDBEAFE),
        iconColor: Color(0xFF2563EB),
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
