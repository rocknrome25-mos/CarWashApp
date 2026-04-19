import 'package:flutter/material.dart';

import '../auth/owner_login_page.dart';
import '../clients/owner_clients_tab.dart';
import '../dashboard/owner_dashboard_tab.dart';
import '../services/owner_services_tab.dart';
import '../settings/owner_settings_tab.dart';
import '../staff/owner_employees_tab.dart';
import 'widgets/owner_top_brand_block.dart';

class OwnerShellPage extends StatefulWidget {
  const OwnerShellPage({super.key});

  @override
  State<OwnerShellPage> createState() => _OwnerShellPageState();
}

class _OwnerShellPageState extends State<OwnerShellPage> {
  int _index = 0;

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
          TextButton.icon(
            onPressed: _openSupport,
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Техподдержка'),
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
}
