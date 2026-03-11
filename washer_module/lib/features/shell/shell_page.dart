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
    final subtitles = [
      'Табель и отметки смены',
      'Текущая смена и записи',
      'Предстоящие рабочие смены',
      'Результаты и доход',
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        centerTitle: false,
        titleSpacing: 16,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Column(
            key: ValueKey(index),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titles[index],
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitles[index],
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton.filledTonal(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Выйти',
              style: IconButton.styleFrom(
                backgroundColor: cs.errorContainer.withValues(alpha: 0.55),
                foregroundColor: cs.onErrorContainer,
              ),
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
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 74,
                backgroundColor: Colors.transparent,
                indicatorColor: cs.primary.withValues(alpha: 0.14),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.72),
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: index,
                backgroundColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (v) => setState(() => index = v),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.access_time_rounded),
                    selectedIcon: Icon(Icons.access_time_filled_rounded),
                    label: 'Часы',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.work_outline_rounded),
                    selectedIcon: Icon(Icons.work_rounded),
                    label: 'Смена',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'График',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart_rounded),
                    label: 'Статистика',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
