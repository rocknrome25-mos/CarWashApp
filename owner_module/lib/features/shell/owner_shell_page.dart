import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/owner_api_client.dart';
import '../auth/owner_login_page.dart';
import '../clients/owner_clients_tab.dart';
import '../dashboard/owner_dashboard_tab.dart';
import '../services/owner_services_tab.dart';
import '../settings/owner_settings_tab.dart';
import '../staff/owner_employees_tab.dart';
import '../alerts/owner_alerts_page.dart';
import 'widgets/owner_top_brand_block.dart';

class OwnerShellPage extends StatefulWidget {
  const OwnerShellPage({super.key});

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

  final Set<String> _shownCriticalAlertIds = {};

  @override
  void initState() {
    super.initState();
    _loadAlerts(showCriticalPopup: true);
    _alertsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadAlerts(showCriticalPopup: true),
    );
  }

  @override
  void dispose() {
    _alertsTimer?.cancel();
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OwnerLoginPage()),
      (route) => false,
    );
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

      if (!mounted) return;

      setState(() {
        _unreadAlerts = unread;
        _criticalUnreadAlerts = criticalUnread;
      });

      if (showCriticalPopup) {
        final alerts = ((data['alerts'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

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
        // ignore
      }
    }

    if (result == 'details') {
      await _openAlertsPage();
    }
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
            onPressed: _openAlertsPage,
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
