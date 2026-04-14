import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api/owner_api_client.dart';
import '../../core/config/app_config.dart';
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

// ignore: library_private_types_in_public_api
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
      child: RefreshIndicator(
        onRefresh: () async {
          setState(_load);
          await Future.wait([
            _summaryFuture,
            _chartFuture,
            _financeFuture,
          ]);
        },
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
                  childBuilder: (data) => _ChartSection(data: data),
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
                  childBuilder: (data) => _SummarySection(data: data),
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
                  childBuilder: (data) => _FinanceSection(data: data),
                );
              },
            ),
          ],
        ),
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
      selected: {value},
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

class _ChartSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ChartSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final points = ((data['points'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (points.isEmpty) {
      return const Text('Нет данных для графика');
    }

    final maxRevenue = points.fold<double>(
      0,
      (prev, item) => math.max(
        prev,
        ((item['revenue'] ?? 0) as num).toDouble(),
      ),
    );

    final maxSuspicious = points.fold<double>(
      0,
      (prev, item) => math.max(
        prev,
        ((item['suspiciousEvents'] ?? 0) as num).toDouble(),
      ),
    );

    final revenueScale = maxRevenue <= 0 ? 1.0 : maxRevenue;
    final suspiciousScale = maxSuspicious <= 0 ? 1.0 : maxSuspicious;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _LegendDot(
              color: Color(0xFF22C55E),
              label: 'Выручка',
            ),
            _LegendDot(
              color: Color(0xFFF43F5E),
              label: 'Подозрительные события',
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final item in points)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 26,
                                  height:
                                      ((item['suspiciousEvents'] ?? 0) as num)
                                                  .toDouble() <=
                                              0
                                          ? 0
                                          : ((((item['suspiciousEvents'] ?? 0)
                                                              as num)
                                                          .toDouble() /
                                                      suspiciousScale) *
                                                  44)
                                              .clamp(6, 44)
                                              .toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF43F5E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 26,
                                  height: ((item['revenue'] ?? 0) as num)
                                              .toDouble() <=
                                          0
                                      ? 4
                                      : ((((item['revenue'] ?? 0) as num)
                                                      .toDouble() /
                                                  revenueScale) *
                                              150)
                                          .clamp(10, 150)
                                          .toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34D399),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item['label'] ?? ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SummarySection({required this.data});

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _rub(int value) => '₽ $value';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final metrics =
        Map<String, dynamic>.from((data['metrics'] as Map?) ?? const {});
    final topServices = ((data['topServices'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final activeShift = data['activeShift'] as Map?;

    final revenue = _intValue(metrics['revenue']);
    final averageCheck = _intValue(metrics['averageCheck']);
    final suspiciousEvents = _intValue(metrics['suspiciousEvents']);
    final servicedBookings = _intValue(metrics['servicedBookings']);
    final newClients = _intValue(metrics['newClients']);
    final clientsTotal = _intValue(metrics['clientsTotal']);
    final clientsWithContacts = _intValue(metrics['clientsWithContacts']);
    final blockedClients = _intValue(metrics['blockedClients']);
    final waitlistWaiting = _intValue(metrics['waitlistWaiting']);
    final admins = _intValue(metrics['admins']);
    final washers = _intValue(metrics['washers']);
    final discountedBookings = _intValue(metrics['discountedBookings']);

    final shiftStatus = activeShift == null ? 'Смена закрыта' : 'Смена открыта';
    final shiftAdminName =
        ((activeShift?['admin'] as Map?)?['name'] ?? 'Не указан').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                title: 'Выручка',
                value: _rub(revenue),
                subtitle: 'За выбранный период',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                title: 'Средний чек',
                value: _rub(averageCheck),
                subtitle: 'По платежам',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                title: 'Обслужено',
                value: '$servicedBookings',
                subtitle: 'Завершённых записей',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                title: 'Подозрительные',
                value: '$suspiciousEvents',
                subtitle: 'Событий',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Основные показатели',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Клиентов за период', value: '$clientsTotal'),
        _SummaryRow(label: 'Новых клиентов', value: '$newClients'),
        _SummaryRow(
          label: 'Клиенты с контактами',
          value: '$clientsWithContacts',
        ),
        _SummaryRow(label: 'Статус смены', value: shiftStatus),
        if (activeShift != null)
          _SummaryRow(label: 'Администратор', value: shiftAdminName),
        _SummaryRow(
          label: 'Снижение стоимости',
          value: '$discountedBookings',
        ),
        _SummaryRow(
          label: 'Заблокированные клиенты',
          value: '$blockedClients',
        ),
        _SummaryRow(
          label: 'В waitlist ожидают',
          value: '$waitlistWaiting',
        ),
        _SummaryRow(label: 'Админы', value: '$admins'),
        _SummaryRow(label: 'Мойщики', value: '$washers'),
        if (topServices.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Топ сервисов',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...topServices.map(
            (service) => _SummaryRow(
              label: '${service['name'] ?? 'Сервис'}',
              value: '${service['bookingsCount'] ?? 0}',
            ),
          ),
        ],
      ],
    );
  }
}

class _FinanceSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _FinanceSection({required this.data});

  String _rub(int value) => '₽ $value';

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _kindLabel(String raw) {
    switch (raw) {
      case 'DEPOSIT':
        return 'Предоплата';
      case 'REMAINING':
        return 'Остаток';
      case 'EXTRA':
        return 'Доплата';
      case 'REFUND':
        return 'Возврат';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods =
        Map<String, dynamic>.from((data['methods'] as Map?) ?? const {});
    final totals =
        Map<String, dynamic>.from((data['totals'] as Map?) ?? const {});
    final kinds = ((data['kinds'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final cash =
        Map<String, dynamic>.from((methods['cash'] as Map?) ?? const {});
    final card =
        Map<String, dynamic>.from((methods['card'] as Map?) ?? const {});
    final contract =
        Map<String, dynamic>.from((methods['contract'] as Map?) ?? const {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                title: 'По картам',
                value: _rub(_intValue(card['amountRub'])),
                subtitle: '${_intValue(card['count'])} оплат',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                title: 'Наличные',
                value: _rub(_intValue(cash['amountRub'])),
                subtitle: '${_intValue(cash['count'])} оплат',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                title: 'Контракт',
                value: _rub(_intValue(contract['amountRub'])),
                subtitle: '${_intValue(contract['count'])} оплат',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoTile(
                title: 'Итого',
                value: _rub(_intValue(totals['amountRub'])),
                subtitle: '${_intValue(totals['count'])} платежей',
              ),
            ),
          ],
        ),
        if (kinds.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Типы платежей',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...kinds.map(
            (item) => _SummaryRow(
              label: _kindLabel('${item['kind']}'),
              value:
                  '${_rub(_intValue(item['amountRub']))} · ${_intValue(item['count'])}',
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _InfoTile({
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
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.right,
          ),
        ],
      ),
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

class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();

  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadEmployees();
  }

  Future<Map<String, dynamic>> _loadEmployees() async {
    final uri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/employees');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Employees request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Employees response is not an object');
    }

    return decoded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data ?? <String, dynamic>{};
          final totals =
              Map<String, dynamic>.from((data['totals'] as Map?) ?? const {});
          final admins = ((data['admins'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final washers = ((data['washers'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _loadEmployees();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('Сотрудники', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Администраторы и мойщики по локации ЖК Рассказово',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        title: 'Всего',
                        value: '${totals['all'] ?? 0}',
                        subtitle: 'Сотрудников',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        title: 'Админы',
                        value: '${totals['admins'] ?? 0}',
                        subtitle: 'Человек',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        title: 'Мойщики',
                        value: '${totals['washers'] ?? 0}',
                        subtitle: 'Человек',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        title: 'Активные',
                        value: '${totals['active'] ?? 0}',
                        subtitle: 'Работают',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Администраторы', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (admins.isEmpty)
                  const Text('Нет администраторов')
                else
                  ...admins.map((e) => _EmployeeCard(data: e)),
                const SizedBox(height: 24),
                Text('Мойщики', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (washers.isEmpty)
                  const Text('Нет мойщиков')
                else
                  ...washers.map((e) => _EmployeeCard(data: e)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _EmployeeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = (data['name'] ?? 'Без имени').toString();
    final phone = (data['phone'] ?? '').toString();
    final role = (data['role'] ?? '').toString();
    final isActive = data['isActive'] == true;

    final roleLabel = role == 'ADMIN' ? 'Администратор' : 'Мойщик';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFF3F4F6),
              child: Icon(
                role == 'ADMIN'
                    ? Icons.badge_outlined
                    : Icons.cleaning_services_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(phone, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    roleLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActive ? 'Активен' : 'Отключён',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
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