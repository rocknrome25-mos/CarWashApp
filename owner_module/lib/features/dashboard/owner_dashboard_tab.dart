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
    await Future.wait([
      _summaryFuture,
      _chartFuture,
      _financeFuture,
    ]);
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
            OwnerPeriodSwitcher(
              value: _period,
              onChanged: _changePeriod,
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _chartFuture,
              builder: (context, snapshot) {
                return OwnerDataCard(
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
                return OwnerDataCard(
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
                return OwnerDataCard(
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
            OwnerLegendDot(
              color: Color(0xFF22C55E),
              label: 'Выручка',
            ),
            OwnerLegendDot(
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
        Text(
          'Основные показатели',
          style: theme.textTheme.titleMedium,
        ),
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
        OwnerSummaryRow(
          label: 'В waitlist ожидают',
          value: '$waitlistWaiting',
        ),
        OwnerSummaryRow(label: 'Админы', value: '$admins'),
        OwnerSummaryRow(label: 'Мойщики', value: '$washers'),
        if (topServices.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Топ сервисов',
            style: theme.textTheme.titleMedium,
          ),
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
          Text(
            'Типы платежей',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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