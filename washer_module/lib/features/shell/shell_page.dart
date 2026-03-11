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
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final pages = [
      ClockPage(api: widget.api, store: widget.store),
      ShiftPage(api: widget.api, store: widget.store),
      SchedulePage(api: widget.api, store: widget.store),
      StatsPage(api: widget.api, store: widget.store),
    ];

    final titles = ['Часы', 'Моя смена', 'График', 'Статистика'];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Text(
            titles[index],
            key: ValueKey(titles[index]),
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Выйти',
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: index,
              backgroundColor: Colors.transparent,
              indicatorColor: cs.primary.withValues(alpha: 0.14),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.access_time_rounded),
                  label: 'Часы',
                ),
                NavigationDestination(
                  icon: Icon(Icons.work_outline_rounded),
                  label: 'Смена',
                ),
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
          ),
        ),
      ),
    );
  }
}
