import 'package:flutter/material.dart';

import '../../core/api/washer_api_client.dart';
import '../../core/storage/washer_session_store.dart';

import '../clock/clock_page.dart';
import '../shift/shift_page.dart';
import '../schedule/schedule_page.dart';
import '../stats/stats_page.dart';
import '../login/login_page.dart';

class ShellPage extends StatefulWidget {
  final WasherApiClient api;
  final WasherSessionStore store;

  const ShellPage({super.key, required this.api, required this.store});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  // ✅ Часы теперь первая вкладка
  int index = 0;

  Future<void> _logout() async {
    await widget.store.clear();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginPage(api: widget.api, store: widget.store),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClockPage(api: widget.api, store: widget.store), // 0
      ShiftPage(api: widget.api, store: widget.store), // 1
      SchedulePage(api: widget.api, store: widget.store), // 2
      StatsPage(api: widget.api, store: widget.store), // 3
    ];

    final titles = ['Часы', 'Моя смена', 'График', 'Статистика'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time), label: 'Часы'),
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Смена'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'График',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Статистика',
          ),
        ],
      ),
    );
  }
}
