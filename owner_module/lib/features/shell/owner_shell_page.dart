import 'package:flutter/material.dart';
import '../../core/api/owner_api_client.dart';
import '../auth/owner_login_page.dart';

class OwnerShellPage extends StatefulWidget {
  const OwnerShellPage({super.key});

  @override
  State<OwnerShellPage> createState() => _OwnerShellPageState();
}

class _OwnerShellPageState extends State<OwnerShellPage> {
  int _index = 0;
  final OwnerApiClient _api = OwnerApiClient();

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const OwnerLoginPage(),
      ),
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
      _SummaryTab(api: _api),
      const _EmployeesTab(),
      const _ClientsTab(),
      const _ServicesTab(),
      const _SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        title: _TopBrandBlock(api: _api),
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

class _TopBrandBlock extends StatelessWidget {
  final OwnerApiClient api;

  const _TopBrandBlock({required this.api});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
            children: [
              Text(
                'ЖК Рассказово',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'г. Москва, бульвар Андрея Тарковского, д. 10',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _SummaryPeriod { day, month, year }

extension SummaryPeriodApiValue on _SummaryPeriod {
  String get apiValue {
    switch (this) {
      case _SummaryPeriod.day:
        return 'day';
      case _SummaryPeriod.month:
        return 'month';
      case _SummaryPeriod.year:
        return 'year';
    }
  }
}

class _SummaryTab extends StatefulWidget {
  final OwnerApiClient api;

  const _SummaryTab({required this.api});

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  _SummaryPeriod _period = _SummaryPeriod.month;

  late Future<Map<String, dynamic>> _summaryFuture;
  late Future<Map<String, dynamic>> _chartFuture;
  late Future<Map<String, dynamic>> _financeFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summaryFuture = widget.api.getOwnerSummary(period: _period.apiValue);
    _chartFuture = widget.api.getOwnerChart(period: _period.apiValue);
    _financeFuture = widget.api.getOwnerFinance(period: _period.apiValue);
  }

  void _changePeriod(_SummaryPeriod value) {
    setState(() {
      _period = value;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Сводка', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Статистика бизнеса по мойке ЖК Рассказово',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          _PeriodSwitcher(
            value: _period,
            onChanged: _changePeriod,
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _chartFuture,
            builder: (context, snapshot) {
              return _DataCard(
                title: 'График',
                snapshot: snapshot,
                childBuilder: (data) => _PrettyJson(data: data),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              return _DataCard(
                title: 'Сводка за период',
                snapshot: snapshot,
                childBuilder: (data) => _PrettyJson(data: data),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _financeFuture,
            builder: (context, snapshot) {
              return _DataCard(
                title: 'Финансовая сводка',
                snapshot: snapshot,
                childBuilder: (data) => _PrettyJson(data: data),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  final _SummaryPeriod value;
  final ValueChanged<_SummaryPeriod> onChanged;

  const _PeriodSwitcher({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_SummaryPeriod>(
      segments: const [
        ButtonSegment<_SummaryPeriod>(
          value: _SummaryPeriod.day,
          label: Text('День'),
        ),
        ButtonSegment<_SummaryPeriod>(
          value: _SummaryPeriod.month,
          label: Text('Месяц'),
        ),
        ButtonSegment<_SummaryPeriod>(
          value: _SummaryPeriod.year,
          label: Text('Год'),
        ),
      ],
      selected: {_SummaryPeriod.day, _SummaryPeriod.month, _SummaryPeriod.year}
              .contains(value)
          ? {value}
          : {_SummaryPeriod.month},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }
}

class _DataCard extends StatelessWidget {
  final String title;
  final AsyncSnapshot<Map<String, dynamic>> snapshot;
  final Widget Function(Map<String, dynamic> data) childBuilder;

  const _DataCard({
    required this.title,
    required this.snapshot,
    required this.childBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget child;
    if (snapshot.connectionState == ConnectionState.waiting) {
      child = const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (snapshot.hasError) {
      child = Text(
        'Ошибка загрузки: ${snapshot.error}',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFB91C1C),
        ),
      );
    } else if (!snapshot.hasData) {
      child = Text(
        'Нет данных',
        style: theme.textTheme.bodyMedium,
      );
    } else {
      child = childBuilder(snapshot.data!);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _PrettyJson extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PrettyJson({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SelectableText(
      data.toString(),
      style: theme.textTheme.bodyMedium,
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PageScaffold({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Раздел в работе',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab();

  @override
  Widget build(BuildContext context) {
    return const _PageScaffold(
      title: 'Сотрудники',
      subtitle: 'Админы, мойщики, права, зарплаты и будущие графики.',
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context) {
    return const _PageScaffold(
      title: 'Клиенты',
      subtitle: 'Статистика по клиентам, авто, тратам и визитам.',
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context) {
    return const _PageScaffold(
      title: 'Сервисы',
      subtitle:
          'Услуги, цены, длительность, категории, повторяемость и цены по типам кузова.',
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const _PageScaffold(
      title: 'Настройки',
      subtitle:
          'Шаблоны сообщений, уведомления владельцу, контакты и рабочие параметры кабинета.',
    );
  }
}