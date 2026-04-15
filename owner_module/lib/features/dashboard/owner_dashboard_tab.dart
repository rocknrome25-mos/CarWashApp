import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api/owner_api_client.dart';
import 'widgets/owner_data_card.dart';
import 'widgets/owner_info_tile.dart';
import 'widgets/owner_legend_dot.dart';
import 'widgets/owner_period_switcher.dart';
import 'widgets/owner_summary_row.dart';

class OwnerDashboardTab extends StatefulWidget {
  const OwnerDashboardTab({super.key});

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  final OwnerApiClient _api = OwnerApiClient();

  OwnerSummaryPeriod _period = OwnerSummaryPeriod.month;

  late Future<Map<String, dynamic>> _summaryFuture;
  late Future<Map<String, dynamic>> _chartFuture;
  late Future<Map<String, dynamic>> _financeFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summaryFuture = _api.getOwnerSummary(period: _period.apiValue);
    _chartFuture = _api.getOwnerChart(period: _period.apiValue);
    _financeFuture = _api.getOwnerFinance(period: _period.apiValue);
  }

  void _changePeriod(OwnerSummaryPeriod value) {
    setState(() {
      _period = value;
      _load();
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_summaryFuture, _chartFuture, _financeFuture]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
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
            OwnerPeriodSwitcher(value: _period, onChanged: _changePeriod),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _chartFuture,
              builder: (context, snapshot) {
                return OwnerDataCard(
                  title: 'График',
                  snapshot: snapshot,
                  childBuilder: (data) =>
                      _OwnerChartSection(data: data, period: _period),
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                return OwnerDataCard(
                  title: 'Сводка за период',
                  snapshot: snapshot,
                  childBuilder: (data) => _OwnerSummarySection(data: data),
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _financeFuture,
              builder: (context, snapshot) {
                return OwnerDataCard(
                  title: 'Финансовая сводка',
                  snapshot: snapshot,
                  childBuilder: (data) => _OwnerFinanceSection(data: data),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerChartSection extends StatefulWidget {
  final Map<String, dynamic> data;
  final OwnerSummaryPeriod period;

  const _OwnerChartSection({required this.data, required this.period});

  @override
  State<_OwnerChartSection> createState() => _OwnerChartSectionState();
}

class _OwnerChartSectionState extends State<_OwnerChartSection> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final points = ((widget.data['points'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (points.isEmpty) {
      return const Text('Нет данных для графика');
    }

    final maxRevenue = points.fold<double>(
      0,
      (prev, item) =>
          math.max(prev, ((item['revenue'] ?? 0) as num).toDouble()),
    );

    final maxSuspicious = points.fold<double>(
      0,
      (prev, item) =>
          math.max(prev, ((item['suspiciousEvents'] ?? 0) as num).toDouble()),
    );

    final revenueScale = maxRevenue <= 0 ? 1.0 : maxRevenue;
    final suspiciousScale = maxSuspicious <= 0 ? 1.0 : maxSuspicious;

    final itemWidth = _itemWidthForPeriod(widget.period);
    final chartWidth = math
        .max(MediaQuery.of(context).size.width - 72, points.length * itemWidth)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            OwnerLegendDot(color: Color(0xFF22C55E), label: 'Выручка'),
            OwnerLegendDot(
              color: Color(0xFFF43F5E),
              label: 'Подозрительные события',
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 290,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < points.length; i++)
                    SizedBox(
                      width: itemWidth.toDouble(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedIndex = _selectedIndex == i ? null : i;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
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
                                        width: 16,
                                        height:
                                            ((points[i]['suspiciousEvents'] ??
                                                            0)
                                                        as num)
                                                    .toDouble() <=
                                                0
                                            ? 0
                                            : ((((points[i]['suspiciousEvents'] ??
                                                                      0)
                                                                  as num)
                                                              .toDouble() /
                                                          suspiciousScale) *
                                                      40)
                                                  .clamp(6, 40)
                                                  .toDouble(),
                                        decoration: BoxDecoration(
                                          color: _selectedIndex == i
                                              ? const Color(0xFFE11D48)
                                              : const Color(0xFFF43F5E),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 16,
                                        height:
                                            ((points[i]['revenue'] ?? 0) as num)
                                                    .toDouble() <=
                                                0
                                            ? 4
                                            : ((((points[i]['revenue'] ?? 0)
                                                                  as num)
                                                              .toDouble() /
                                                          revenueScale) *
                                                      150)
                                                  .clamp(10, 150)
                                                  .toDouble(),
                                        decoration: BoxDecoration(
                                          color: _selectedIndex == i
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF34D399),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 22,
                                child: Center(
                                  child: Text(
                                    _axisLabel(points[i], i),
                                    maxLines: 1,
                                    overflow: TextOverflow.visible,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: _selectedIndex == i
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF6B7280),
                                      fontWeight: _selectedIndex == i
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedIndex != null)
          _SelectedPointCard(
            label: _tooltipLabel(points[_selectedIndex!]),
            revenue: _intValue(points[_selectedIndex!]['revenue']),
            suspiciousEvents: _intValue(
              points[_selectedIndex!]['suspiciousEvents'],
            ),
          )
        else
          Text(
            'Нажмите на столбик, чтобы посмотреть детали.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
      ],
    );
  }

  int _itemWidthForPeriod(OwnerSummaryPeriod period) {
    switch (period) {
      case OwnerSummaryPeriod.day:
        return 44;
      case OwnerSummaryPeriod.month:
        return 34;
      case OwnerSummaryPeriod.year:
        return 44;
    }
  }

  String _axisLabel(Map<String, dynamic> point, int index) {
    final raw = (point['label'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return '${index + 1}';
    }

    switch (widget.period) {
      case OwnerSummaryPeriod.day:
        return raw;
      case OwnerSummaryPeriod.month:
        return raw;
      case OwnerSummaryPeriod.year:
        return raw;
    }
  }

  String _tooltipLabel(Map<String, dynamic> point) {
    final raw = (point['label'] ?? '').toString().trim();
    if (raw.isEmpty) return 'Период';

    switch (widget.period) {
      case OwnerSummaryPeriod.day:
        return 'Час: $raw';
      case OwnerSummaryPeriod.month:
        return 'День: $raw';
      case OwnerSummaryPeriod.year:
        return 'Месяц: $raw';
    }
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class _SelectedPointCard extends StatelessWidget {
  final String label;
  final int revenue;
  final int suspiciousEvents;

  const _SelectedPointCard({
    required this.label,
    required this.revenue,
    required this.suspiciousEvents,
  });

  String _rub(int value) => '₽ $value';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Выручка: ${_rub(revenue)}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Подозрительные события: $suspiciousEvents',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _OwnerSummarySection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _OwnerSummarySection({required this.data});

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _rub(int value) => '₽ $value';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final metrics = Map<String, dynamic>.from(
      (data['metrics'] as Map?) ?? const {},
    );
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
              child: OwnerInfoTile(
                title: 'Выручка',
                value: _rub(revenue),
                subtitle: 'За выбранный период',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OwnerInfoTile(
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
              child: OwnerInfoTile(
                title: 'Обслужено',
                value: '$servicedBookings',
                subtitle: 'Завершённых записей',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OwnerInfoTile(
                title: 'Подозрительные',
                value: '$suspiciousEvents',
                subtitle: 'Событий',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Основные показатели', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        OwnerSummaryRow(label: 'Клиентов за период', value: '$clientsTotal'),
        OwnerSummaryRow(label: 'Новых клиентов', value: '$newClients'),
        OwnerSummaryRow(
          label: 'Клиенты с контактами',
          value: '$clientsWithContacts',
        ),
        OwnerSummaryRow(label: 'Статус смены', value: shiftStatus),
        if (activeShift != null)
          OwnerSummaryRow(label: 'Администратор', value: shiftAdminName),
        OwnerSummaryRow(
          label: 'Снижение стоимости',
          value: '$discountedBookings',
        ),
        OwnerSummaryRow(
          label: 'Заблокированные клиенты',
          value: '$blockedClients',
        ),
        OwnerSummaryRow(label: 'В waitlist ожидают', value: '$waitlistWaiting'),
        OwnerSummaryRow(label: 'Админы', value: '$admins'),
        OwnerSummaryRow(label: 'Мойщики', value: '$washers'),
        if (topServices.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Топ сервисов', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          ...topServices.map(
            (service) => OwnerSummaryRow(
              label: '${service['name'] ?? 'Сервис'}',
              value: '${service['bookingsCount'] ?? 0}',
            ),
          ),
        ],
      ],
    );
  }
}

class _OwnerFinanceSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _OwnerFinanceSection({required this.data});

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
    final methods = Map<String, dynamic>.from(
      (data['methods'] as Map?) ?? const {},
    );
    final totals = Map<String, dynamic>.from(
      (data['totals'] as Map?) ?? const {},
    );
    final kinds = ((data['kinds'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final cash = Map<String, dynamic>.from(
      (methods['cash'] as Map?) ?? const {},
    );
    final card = Map<String, dynamic>.from(
      (methods['card'] as Map?) ?? const {},
    );
    final contract = Map<String, dynamic>.from(
      (methods['contract'] as Map?) ?? const {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OwnerInfoTile(
                title: 'По картам',
                value: _rub(_intValue(card['amountRub'])),
                subtitle: '${_intValue(card['count'])} оплат',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OwnerInfoTile(
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
              child: OwnerInfoTile(
                title: 'Контракт',
                value: _rub(_intValue(contract['amountRub'])),
                subtitle: '${_intValue(contract['count'])} оплат',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OwnerInfoTile(
                title: 'Итого',
                value: _rub(_intValue(totals['amountRub'])),
                subtitle: '${_intValue(totals['count'])} платежей',
              ),
            ),
          ],
        ),
        if (kinds.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Типы платежей', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...kinds.map(
            (item) => OwnerSummaryRow(
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
