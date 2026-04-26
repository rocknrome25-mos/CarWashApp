import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api/owner_api_client.dart';
import '../../core/config/app_config.dart';

class OwnerClientsTab extends StatefulWidget {
  const OwnerClientsTab({super.key});

  @override
  State<OwnerClientsTab> createState() => _OwnerClientsTabState();
}

class _OwnerClientsTabState extends State<OwnerClientsTab> {
  final OwnerApiClient _api = OwnerApiClient();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _clientsSectionKey = GlobalKey();

  late Future<Map<String, dynamic>> _future;
  Timer? _searchDebounce;
  Timer? _autoRefreshTimer;

  String _period = 'month';
  String _query = '';
  String _segmentFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _future = _load();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    return _api.getOwnerClients(period: _period, q: _query, limit: 100);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  void _changePeriod(String value) {
    if (_period == value) return;
    setState(() {
      _period = value;
      _future = _load();
    });
  }

  void _changeSegmentFilter(String value) {
    if (_segmentFilter == value) return;
    setState(() => _segmentFilter = value);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _clientsSectionKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _future = _load();
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _future = _load();
    });
  }

  void _openClientDetail(Map<String, dynamic> client) {
    final clientId = (client['clientId'] ?? '').toString();
    if (clientId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OwnerClientDetailPage(
          clientId: clientId,
          fallbackName: (client['name'] ?? 'Клиент').toString(),
          period: _period,
        ),
      ),
    );
  }

  void _openVisitClientDetail(Map<String, dynamic> visit) {
    final clientId = (visit['clientId'] ?? '').toString();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У визита не указан клиент')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OwnerClientDetailPage(
          clientId: clientId,
          fallbackName: (visit['clientName'] ?? 'Клиент').toString(),
          period: _period,
        ),
      ),
    );
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ошибка загрузки: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final totals = _map(data['totals']);
          final analytics = _map(data['analytics']);

          final rawClients = _list(data['clients']);
          final clients = rawClients.map(_clientWithComputedSegment).toList();

          final filteredClients = clients
              .where((client) => _passesSegmentFilter(client, _segmentFilter))
              .toList();

          final sortedClients = _sortClientsForDisplay(
            filteredClients,
            _segmentFilter,
          );

          final topClients = _list(
            data['topClients'],
          ).map(_clientWithComputedSegment).toList();
          final recentVisits = _list(data['recentVisits'] ?? data['gallery']);
          final byGender = _list(analytics['byGender']);
          final byBodyType = _list(analytics['byBodyType']);

          final vipCount = clients.where((c) => c['isVip'] == true).length;
          final frequentCount = clients
              .where((c) => c['segment'] == 'FREQUENT')
              .length;
          final rareCount = clients.where((c) => c['segment'] == 'RARE').length;
          final lostCount = clients.where((c) => c['isLost'] == true).length;
          final debtCount = clients.where((c) => c['hasDebt'] == true).length;
          final selectedLabel = _segmentFilterTitle(_segmentFilter);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Клиенты',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Аналитика клиентов, визитов, оплат и качества работы',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Обновить',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('День')),
                    ButtonSegment(value: 'month', label: Text('Месяц')),
                    ButtonSegment(value: 'year', label: Text('Год')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (value) => _changePeriod(value.first),
                ),
                const SizedBox(height: 16),
                _ResponsiveMetricGrid(
                  children: [
                    _MetricTile(
                      title: 'Всего клиентов',
                      value: '${_asInt(totals['clientsTotal'])}',
                      subtitle: 'В базе мойки',
                      icon: Icons.people_outline,
                    ),
                    _MetricTile(
                      title: 'Новые',
                      value: '${_asInt(totals['newClients'])}',
                      subtitle: _periodLabel(_period),
                      icon: Icons.person_add_alt_1_outlined,
                    ),
                    _MetricTile(
                      title: 'С контактами',
                      value: '${_asInt(totals['withContacts'])}',
                      subtitle: 'Можно связаться',
                      icon: Icons.contact_phone_outlined,
                    ),
                    _MetricTile(
                      title: 'VIP',
                      value: '$vipCount',
                      subtitle: 'Лучшие по тратам',
                      icon: Icons.diamond_outlined,
                    ),
                    _MetricTile(
                      title: 'Частые',
                      value: '$frequentCount',
                      subtitle: 'Регулярные визиты',
                      icon: Icons.repeat,
                    ),
                    _MetricTile(
                      title: 'Пропали',
                      value: '$lostCount',
                      subtitle: 'Нет визитов 30+ дней',
                      icon: Icons.person_off_outlined,
                    ),
                    _MetricTile(
                      title: 'Должники',
                      value: '$debtCount',
                      subtitle: 'Есть CONTRACT',
                      icon: Icons.warning_amber_outlined,
                    ),
                    _MetricTile(
                      title: 'Заблокированы',
                      value: '${_asInt(totals['blockedClients'])}',
                      subtitle: 'Проблемные',
                      icon: Icons.block,
                    ),
                  ],
                ),
                if (topClients.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'Топ клиенты',
                    subtitle: 'Кто принёс больше всего денег',
                  ),
                  const SizedBox(height: 12),
                  ...topClients.map(
                    (client) => _TopClientCard(
                      client: client,
                      onTap: () => _openClientDetail(client),
                    ),
                  ),
                ],
                if (recentVisits.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'Галерея последних визитов',
                    subtitle: 'Фото, авто, сумма, оплата и время завершения',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 232,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentVisits.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final visit = recentVisits[index];
                        return _RecentVisitCard(
                          visit: visit,
                          onTap: () => _openVisitClientDetail(visit),
                        );
                      },
                    ),
                  ),
                ],
                if (byGender.isNotEmpty || byBodyType.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'Срезы базы',
                    subtitle: 'Пол и типы кузова',
                  ),
                  const SizedBox(height: 12),
                  if (byGender.isNotEmpty)
                    _ChipWrapCard(
                      title: 'По полу',
                      items: byGender
                          .map(
                            (e) =>
                                '${e['label'] ?? e['gender']}: ${_asInt(e['count'])}',
                          )
                          .toList(),
                    ),
                  if (byBodyType.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ChipWrapCard(
                      title: 'По типам кузова',
                      items: byBodyType
                          .map(
                            (e) =>
                                '${e['bodyType'] ?? 'Не указан'}: ${_asInt(e['count'])}',
                          )
                          .toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _clientsSectionKey,
                  child: const _SectionHeader(
                    title: 'Поиск и фильтр клиентов',
                    subtitle: 'Найдите клиента и выберите нужный сегмент',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск: имя, телефон, номер авто',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 14),
                _SegmentFilterBar(
                  selected: _segmentFilter,
                  onChanged: _changeSegmentFilter,
                  counts: {
                    'ALL': clients.length,
                    'VIP': vipCount,
                    'FREQUENT': frequentCount,
                    'LOST': lostCount,
                    'DEBT': debtCount,
                    'RARE': rareCount,
                  },
                ),
                const SizedBox(height: 10),
                _ActiveFilterInfoCard(
                  title: selectedLabel,
                  shown: sortedClients.length,
                  total: clients.length,
                  onReset: _segmentFilter == 'ALL'
                      ? null
                      : () => _changeSegmentFilter('ALL'),
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: selectedLabel,
                  subtitle: sortedClients.isEmpty
                      ? 'Клиентов по текущему фильтру нет'
                      : 'Показано ${sortedClients.length} из ${clients.length}. Нажмите на клиента, чтобы открыть карточку',
                ),
                const SizedBox(height: 12),
                if (sortedClients.isEmpty)
                  _EmptyCard(
                    text: _segmentFilter == 'ALL'
                        ? 'Клиенты не найдены'
                        : 'В сегменте “$selectedLabel” клиентов нет',
                  )
                else
                  ...sortedClients.map(
                    (client) => _ClientListCard(
                      client: client,
                      onTap: () => _openClientDetail(client),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OwnerClientDetailPage extends StatefulWidget {
  final String clientId;
  final String fallbackName;
  final String period;

  const _OwnerClientDetailPage({
    required this.clientId,
    required this.fallbackName,
    required this.period,
  });

  @override
  State<_OwnerClientDetailPage> createState() => _OwnerClientDetailPageState();
}

class _OwnerClientDetailPageState extends State<_OwnerClientDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final uri = Uri.parse(
      '${AppConfig.defaultBaseUrl}/owner/clients/${widget.clientId}',
    ).replace(queryParameters: {'period': widget.period});

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Client detail request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Client detail response is invalid');
    }

    return decoded;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fallbackName),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ошибка загрузки: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final client = _clientWithComputedSegment(_map(data['client']));
          final totals = _map(client['totals']);
          final paymentMethods = _map(client['paymentMethods']);
          final cars = _list(client['cars']);
          final visits = _list(client['visits']);

          final isBlocked = client['isBlocked'] == true;
          final name = (client['name'] ?? 'Без имени').toString();
          final phone = (client['phone'] ?? '').toString();
          final debt = _asInt(client['contractDebtRub']);
          final daysSinceLastVisit = _asInt(client['daysSinceLastVisit']);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFFFEEE8),
                      child: Text(
                        name.trim().isEmpty
                            ? '?'
                            : name.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 6),
                          Text(
                            phone.isEmpty ? 'Телефон не указан' : phone,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SegmentBadge(client: client),
                              _SmallChip(
                                text: isBlocked ? 'Заблокирован' : 'Активен',
                                background: isBlocked
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFDCFCE7),
                              ),
                              _SmallChip(
                                text:
                                    'Последний визит: ${_formatDateTime(client['lastVisitAt'])}',
                              ),
                              if (daysSinceLastVisit > 0)
                                _SmallChip(
                                  text: 'Не был $daysSinceLastVisit дн.',
                                ),
                              if (debt > 0)
                                _SmallChip(
                                  text: 'Долг: ${_rub(debt)}',
                                  background: const Color(0xFFFEF3C7),
                                ),
                            ],
                          ),
                          if (isBlocked &&
                              (client['blockReason'] ?? '')
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Причина блокировки: ${client['blockReason']}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ResponsiveMetricGrid(
                  children: [
                    _MetricTile(
                      title: 'Потратил всего',
                      value: _rub(
                        _asInt(totals['totalSpent'] ?? client['totalSpent']),
                      ),
                      subtitle: 'Все оплаты',
                      icon: Icons.payments_outlined,
                    ),
                    _MetricTile(
                      title: 'За период',
                      value: _rub(
                        _asInt(totals['periodSpent'] ?? client['periodSpent']),
                      ),
                      subtitle: _periodLabel(widget.period),
                      icon: Icons.trending_up,
                    ),
                    _MetricTile(
                      title: 'Визиты',
                      value: '${_asInt(totals['visits'] ?? client['visits'])}',
                      subtitle:
                          client['visitsFrequencyLabel']?.toString() ??
                          'Завершённые',
                      icon: Icons.local_car_wash_outlined,
                    ),
                    _MetricTile(
                      title: 'Средний чек',
                      value: _rub(
                        _asInt(
                          totals['averageCheck'] ?? client['averageCheck'],
                        ),
                      ),
                      subtitle: 'По визитам',
                      icon: Icons.receipt_long_outlined,
                    ),
                    _MetricTile(
                      title: 'Контракт / долг',
                      value: _rub(
                        _asInt(
                          totals['contractDebtRub'] ??
                              client['contractDebtRub'],
                        ),
                      ),
                      subtitle: 'Оплата CONTRACT',
                      icon: Icons.warning_amber_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Оплаты',
                  subtitle: 'Структура платежей клиента',
                ),
                const SizedBox(height: 12),
                _PaymentMethodsCard(methods: paymentMethods),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Авто клиента',
                  subtitle: '${cars.length} авто',
                ),
                const SizedBox(height: 12),
                if (cars.isEmpty)
                  const _EmptyCard(text: 'Авто не указаны')
                else
                  ...cars.map((car) => _CarCard(car: car, visits: visits)),
                if (visits.any(
                  (visit) => _visitBestPhotoUrl(visit) != null,
                )) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'Фото авто по визитам',
                    subtitle:
                        'Последние фотографии, разложенные по автомобилям',
                  ),
                  const SizedBox(height: 12),
                  if (cars.isEmpty)
                    _CarVisitPhotosSection(
                      car: const <String, dynamic>{},
                      visits: visits,
                    )
                  else
                    ...cars.map(
                      (car) => _CarVisitPhotosSection(car: car, visits: visits),
                    ),
                ],
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'История визитов',
                  subtitle:
                      'Услуги, оплаты, фото до/после и контроль норматива',
                ),
                const SizedBox(height: 12),
                if (visits.isEmpty)
                  const _EmptyCard(text: 'Визитов пока нет')
                else
                  ...visits.map((visit) => _VisitDetailCard(visit: visit)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SegmentFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final Map<String, int> counts;

  const _SegmentFilterBar({
    required this.selected,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('ALL', 'Все', Icons.people_outline),
      ('VIP', 'VIP', Icons.diamond_outlined),
      ('FREQUENT', 'Частые', Icons.repeat),
      ('RARE', 'Редкие', Icons.hourglass_empty),
      ('LOST', 'Пропали', Icons.person_off_outlined),
      ('DEBT', 'Должники', Icons.warning_amber_outlined),
    ].where((item) => item.$1 == 'ALL' || (counts[item.$1] ?? 0) > 0).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final isSelected = selected == item.$1;
          final count = counts[item.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              onSelected: (_) => onChanged(item.$1),
              avatar: Icon(item.$3, size: 18),
              label: Text('${item.$2} $count'),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActiveFilterInfoCard extends StatelessWidget {
  final String title;
  final int shown;
  final int total;
  final VoidCallback? onReset;

  const _ActiveFilterInfoCard({
    required this.title,
    required this.shown,
    required this.total,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Фильтр: $title • показано $shown из $total',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (onReset != null)
            TextButton(onPressed: onReset, child: const Text('Сбросить')),
        ],
      ),
    );
  }
}

class _SegmentBadge extends StatelessWidget {
  final Map<String, dynamic> client;

  const _SegmentBadge({required this.client});

  @override
  Widget build(BuildContext context) {
    final segment = (client['segment'] ?? 'REGULAR').toString();
    final label = (client['segmentLabel'] ?? _segmentLabel(segment)).toString();
    final background = _segmentColor(segment);

    return _SmallChip(text: label, background: background);
  }
}

class _ClientListCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  const _ClientListCard({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (client['name'] ?? 'Без имени').toString();
    final phone = (client['phone'] ?? '').toString();
    final cars = _list(client['cars']);
    final firstCar = cars.isNotEmpty ? cars.first : const <String, dynamic>{};
    final isBlocked = client['isBlocked'] == true;
    final debt = _asInt(client['contractDebtRub']);
    final daysSinceLastVisit = _asInt(client['daysSinceLastVisit']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: theme.textTheme.titleMedium),
                  ),
                  _SegmentBadge(client: client),
                  if (isBlocked) ...[
                    const SizedBox(width: 8),
                    const _SmallChip(
                      text: 'Блок',
                      background: Color(0xFFFEE2E2),
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                phone.isEmpty ? 'Телефон не указан' : phone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
              if (firstCar.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '${firstCar['plate'] ?? ''} • ${firstCar['make'] ?? ''} ${firstCar['model'] ?? ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallChip(text: 'Визитов: ${_asInt(client['visits'])}'),
                  _SmallChip(
                    text: 'Сумма: ${_rub(_asInt(client['totalSpent']))}',
                  ),
                  _SmallChip(
                    text:
                        'Средний чек: ${_rub(_asInt(client['averageCheck']))}',
                  ),
                  _SmallChip(
                    text: 'Период: ${_rub(_asInt(client['periodSpent']))}',
                  ),
                  _SmallChip(
                    text:
                        (client['visitsFrequencyLabel'] ??
                                'Частота не определена')
                            .toString(),
                  ),
                  if (daysSinceLastVisit > 0)
                    _SmallChip(text: 'Не был $daysSinceLastVisit дн.'),
                  if (debt > 0)
                    _SmallChip(
                      text: 'Долг: ${_rub(debt)}',
                      background: const Color(0xFFFEF3C7),
                    ),
                  _SmallChip(
                    text:
                        'Последняя: ${_formatDateTime(client['lastVisitAt'])}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  const _TopClientCard({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFECFDF5),
          child: Icon(
            Icons.workspace_premium_outlined,
            color: Color(0xFF059669),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text((client['name'] ?? 'Без имени').toString())),
            _SegmentBadge(client: client),
          ],
        ),
        subtitle: Text(
          '${client['phone'] ?? ''} • ${_asInt(client['visits'])} визитов',
        ),
        trailing: Text(
          _rub(_asInt(client['totalSpent'])),
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _RecentVisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final VoidCallback? onTap;

  const _RecentVisitCard({required this.visit, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final car = _map(visit['car']);
    final service = _map(visit['service']);
    final photoUrl = _resolvePhotoUrl((visit['photoUrl'] ?? '').toString());

    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: photoUrl == null
                    ? Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (car['plate'] ?? 'Номер не указан').toString(),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (visit['clientName'] ?? 'Клиент').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${service['name'] ?? 'Услуга'} • ${_rub(_asInt(visit['amountRub'] ?? visit['amount']))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDateTime(
                              visit['finishedAt'] ?? visit['dateTime'],
                            ),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitDetailCard extends StatelessWidget {
  final Map<String, dynamic> visit;

  const _VisitDetailCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final car = _map(visit['car']);
    final service = _map(visit['service']);
    final paymentMethods = _map(visit['paymentMethods']);
    final photos = _map(visit['photos']);
    final timeControl = _map(visit['timeControl']);
    final addons = _list(visit['addons']);

    final beforeUrl = _resolvePhotoUrl((photos['beforeUrl'] ?? '').toString());
    final afterUrl = _resolvePhotoUrl((photos['afterUrl'] ?? '').toString());
    final deltaMin = _asInt(timeControl['deltaMin']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${car['plate'] ?? 'Авто'} • ${service['name'] ?? 'Услуга'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  _rub(_asInt(visit['amountRub'])),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Завершено: ${_formatDateTime(visit['finishedAt'] ?? visit['dateTime'])}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallChip(
                  text: 'Нал: ${_rub(_asInt(paymentMethods['cash']))}',
                ),
                _SmallChip(
                  text: 'Карта: ${_rub(_asInt(paymentMethods['card']))}',
                ),
                _SmallChip(
                  text: 'Контракт: ${_rub(_asInt(paymentMethods['contract']))}',
                ),
                _SmallChip(
                  text:
                      'Норматив: ${_asInt(timeControl['plannedDurationMin'])} мин',
                ),
                _SmallChip(
                  text: 'Факт: ${_asInt(timeControl['actualDurationMin'])} мин',
                  background: deltaMin > 0
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEFF6FF),
                ),
              ],
            ),
            if (addons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Доп. услуги', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ...addons.map(
                (addon) => Text(
                  '• ${addon['name'] ?? 'Доп. услуга'} × ${addon['qty'] ?? 1} — ${_rub(_asInt(addon['priceRub']))}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (beforeUrl != null || afterUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PhotoBox(title: 'До', url: beforeUrl),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoBox(title: 'После', url: afterUrl),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final List<Map<String, dynamic>> visits;

  const _CarCard({required this.car, this.visits = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = _latestCarPhotoUrl(car, visits);
    final plate = (car['plate'] ?? 'Номер не указан').toString();
    final make = (car['make'] ?? '').toString();
    final model = (car['model'] ?? '').toString();
    final bodyType = (car['bodyType'] ?? 'кузов не указан').toString();
    final year = (car['year'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 92,
            child: photoUrl == null
                ? Container(
                    color: const Color(0xFFEFF6FF),
                    child: const Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF2563EB),
                    ),
                  )
                : Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFEFF6FF),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plate, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '$make $model • $bodyType',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (year.trim().isNotEmpty && year != 'null') ...[
                    const SizedBox(height: 6),
                    _SmallChip(text: 'Год: $year'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarVisitPhotosSection extends StatelessWidget {
  final Map<String, dynamic> car;
  final List<Map<String, dynamic>> visits;

  const _CarVisitPhotosSection({required this.car, required this.visits});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredVisits = visits
        .where((visit) => car.isEmpty || _visitMatchesCar(visit, car))
        .where((visit) => _visitBestPhotoUrl(visit) != null)
        .toList();

    if (filteredVisits.isEmpty) return const SizedBox.shrink();

    final plate = car.isEmpty
        ? 'Все авто'
        : (car['plate'] ?? 'Номер не указан').toString();
    final subtitle = car.isEmpty
        ? '${filteredVisits.length} фото'
        : '${car['make'] ?? ''} ${car['model'] ?? ''} • ${filteredVisits.length} фото';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plate, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.photo_library_outlined, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 188,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredVisits.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _VisitPhotoStripCard(visit: filteredVisits[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitPhotoStripCard extends StatelessWidget {
  final Map<String, dynamic> visit;

  const _VisitPhotoStripCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = _map(visit['service']);
    final car = _map(visit['car']);
    final photoUrl = _visitBestPhotoUrl(visit);
    final photos = _map(visit['photos']);
    final beforeUrl = _resolvePhotoUrl((photos['beforeUrl'] ?? '').toString());
    final afterUrl = _resolvePhotoUrl((photos['afterUrl'] ?? '').toString());

    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: photoUrl == null
                    ? Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (car['plate'] ?? _visitPlate(visit) ?? 'Авто').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${service['name'] ?? 'Услуга'} • ${_rub(_asInt(visit['amountRub']))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (beforeUrl != null) const _SmallChip(text: 'До'),
                        if (afterUrl != null) const _SmallChip(text: 'После'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  final Map<String, dynamic> methods;

  const _PaymentMethodsCard({required this.methods});

  @override
  Widget build(BuildContext context) {
    final cash = _asInt(methods['cash']);
    final card = _asInt(methods['card']);
    final contract = _asInt(methods['contract']);
    final total = cash + card + contract;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _PaymentMethodTile(
                    title: 'Наличные',
                    value: _rub(cash),
                    subtitle: _percentLabel(cash, total),
                    icon: Icons.payments_outlined,
                  ),
                ),
                Expanded(
                  child: _PaymentMethodTile(
                    title: 'Карта',
                    value: _rub(card),
                    subtitle: _percentLabel(card, total),
                    icon: Icons.credit_card,
                  ),
                ),
                Expanded(
                  child: _PaymentMethodTile(
                    title: 'Контракт',
                    value: _rub(contract),
                    subtitle: _percentLabel(contract, total),
                    icon: Icons.description_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total <= 0 ? 0 : cash / total,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _PaymentMethodTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon),
        const SizedBox(height: 6),
        Text(title, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String title;
  final String? url;

  const _PhotoBox({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: url == null
                ? Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.image_not_supported_outlined),
                  )
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 900
            ? (width - 36) / 4
            : width >= 650
            ? (width - 24) / 3
            : (width - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
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
          Icon(icon, size: 20, color: const Color(0xFF2563EB)),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _ChipWrapCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _ChipWrapCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) => _SmallChip(text: item)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;
  final Color background;

  const _SmallChip({
    required this.text,
    this.background = const Color(0xFFF3F4F6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];

  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

String _rub(int value) => '₽ $value';

String _periodLabel(String period) {
  switch (period) {
    case 'day':
      return 'за день';
    case 'year':
      return 'за год';
    case 'month':
    default:
      return 'за месяц';
  }
}

String _formatDateTime(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty || value == 'null') return '—';

  final dt = DateTime.tryParse(value);
  if (dt == null) return value;

  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}

String? _resolvePhotoUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == 'null') return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('/')) return '${AppConfig.defaultBaseUrl}$value';
  return '${AppConfig.defaultBaseUrl}/$value';
}

String? _latestCarPhotoUrl(
  Map<String, dynamic> car,
  List<Map<String, dynamic>> visits,
) {
  for (final visit in visits) {
    if (_visitMatchesCar(visit, car)) {
      final url = _visitBestPhotoUrl(visit);
      if (url != null) return url;
    }
  }
  return null;
}

bool _visitMatchesCar(Map<String, dynamic> visit, Map<String, dynamic> car) {
  final visitCar = _map(visit['car']);
  final carId = (car['id'] ?? '').toString();
  final visitCarId = (visitCar['id'] ?? '').toString();
  if (carId.isNotEmpty && visitCarId.isNotEmpty && carId == visitCarId) {
    return true;
  }

  final carPlate = (car['plate'] ?? '').toString().trim().toUpperCase();
  final visitPlate = _visitPlate(visit)?.trim().toUpperCase() ?? '';
  return carPlate.isNotEmpty && visitPlate.isNotEmpty && carPlate == visitPlate;
}

String? _visitPlate(Map<String, dynamic> visit) {
  final visitCar = _map(visit['car']);
  final plate = (visitCar['plate'] ?? '').toString().trim();
  return plate.isEmpty || plate == 'null' ? null : plate;
}

String? _visitBestPhotoUrl(Map<String, dynamic> visit) {
  final photos = _map(visit['photos']);

  final afterUrl = _resolvePhotoUrl((photos['afterUrl'] ?? '').toString());
  if (afterUrl != null) return afterUrl;

  final beforeUrl = _resolvePhotoUrl((photos['beforeUrl'] ?? '').toString());
  if (beforeUrl != null) return beforeUrl;

  final photoUrl = _resolvePhotoUrl((visit['photoUrl'] ?? '').toString());
  if (photoUrl != null) return photoUrl;

  final allPhotos = _list(photos['all']);
  for (final photo in allPhotos) {
    final url = _resolvePhotoUrl((photo['url'] ?? '').toString());
    if (url != null) return url;
  }

  return null;
}

Map<String, dynamic> _clientWithComputedSegment(Map<String, dynamic> client) {
  final result = Map<String, dynamic>.from(client);
  final totals = _map(result['totals']);

  final totalSpent = _asInt(result['totalSpent'] ?? totals['totalSpent']);
  final periodSpent = _asInt(result['periodSpent'] ?? totals['periodSpent']);
  final visits = _asInt(result['visits'] ?? totals['visits']);
  final visitsTotal = _asInt(
    result['visitsTotal'] ?? totals['visitsTotal'] ?? visits,
  );
  final averageCheck = _asInt(result['averageCheck'] ?? totals['averageCheck']);
  final contractDebtRub = _asInt(
    result['contractDebtRub'] ?? totals['contractDebtRub'],
  );

  final daysSinceLastVisit = _daysSince(result['lastVisitAt']);
  final hasDebt = contractDebtRub > 0;
  final isLost = daysSinceLastVisit >= 30 && visitsTotal > 0;
  final isVip = totalSpent >= 50000 || visits >= 10 || averageCheck >= 7000;

  String segment;
  if (hasDebt) {
    segment = 'DEBT';
  } else if (isLost) {
    segment = 'LOST';
  } else if (isVip) {
    segment = 'VIP';
  } else if (visits >= 5 || (daysSinceLastVisit <= 14 && visits >= 2)) {
    segment = 'FREQUENT';
  } else if (visits <= 1 || daysSinceLastVisit >= 45) {
    segment = 'RARE';
  } else {
    segment = 'REGULAR';
  }

  final frequencyLabel = _frequencyLabel(
    visits: visits,
    daysSinceLastVisit: daysSinceLastVisit,
  );

  result['totalSpent'] = totalSpent;
  result['periodSpent'] = periodSpent;
  result['visits'] = visits;
  result['visitsTotal'] = visitsTotal;
  result['averageCheck'] = averageCheck;
  result['contractDebtRub'] = contractDebtRub;
  result['daysSinceLastVisit'] = daysSinceLastVisit;
  result['hasDebt'] = hasDebt;
  result['isLost'] = isLost;
  result['isVip'] = isVip;
  result['segment'] = result['segment'] ?? segment;
  result['segmentLabel'] = result['segmentLabel'] ?? _segmentLabel(segment);
  result['visitsFrequencyLabel'] =
      result['visitsFrequencyLabel'] ?? frequencyLabel;

  return result;
}

bool _passesSegmentFilter(Map<String, dynamic> client, String filter) {
  if (filter == 'ALL') return true;
  if (filter == 'DEBT') return client['hasDebt'] == true;
  if (filter == 'LOST') return client['isLost'] == true;
  if (filter == 'VIP') return client['isVip'] == true;
  return (client['segment'] ?? '').toString() == filter;
}

List<Map<String, dynamic>> _sortClientsForDisplay(
  List<Map<String, dynamic>> clients,
  String filter,
) {
  final result = [...clients];

  result.sort((a, b) {
    final groupCompare = _segmentSortRank(
      a,
      filter,
    ).compareTo(_segmentSortRank(b, filter));
    if (groupCompare != 0) return groupCompare;

    final spentCompare = _asInt(
      b['totalSpent'],
    ).compareTo(_asInt(a['totalSpent']));
    if (spentCompare != 0) return spentCompare;

    final visitsCompare = _asInt(b['visits']).compareTo(_asInt(a['visits']));
    if (visitsCompare != 0) return visitsCompare;

    final lastA = DateTime.tryParse((a['lastVisitAt'] ?? '').toString());
    final lastB = DateTime.tryParse((b['lastVisitAt'] ?? '').toString());

    if (lastA != null && lastB != null) {
      return lastB.compareTo(lastA);
    }

    return 0;
  });

  return result;
}

int _segmentSortRank(Map<String, dynamic> client, String filter) {
  if (filter != 'ALL') return 0;

  final hasDebt = client['hasDebt'] == true;
  final isVip = client['isVip'] == true;
  final isLost = client['isLost'] == true;
  final segment = (client['segment'] ?? '').toString();

  if (hasDebt) return 0;
  if (isVip) return 1;
  if (segment == 'FREQUENT') return 2;
  if (segment == 'REGULAR') return 3;
  if (isLost || segment == 'LOST') return 4;
  if (segment == 'RARE') return 5;

  return 6;
}

int _daysSince(dynamic raw) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty || value == 'null') return 0;
  final dt = DateTime.tryParse(value);
  if (dt == null) return 0;
  final now = DateTime.now();
  return now.difference(dt.toLocal()).inDays.clamp(0, 9999);
}

String _segmentFilterTitle(String segment) {
  switch (segment) {
    case 'VIP':
      return 'VIP клиенты';
    case 'FREQUENT':
      return 'Частые клиенты';
    case 'RARE':
      return 'Редкие клиенты';
    case 'LOST':
      return 'Пропавшие клиенты';
    case 'DEBT':
      return 'Клиенты с долгом';
    case 'ALL':
    default:
      return 'Все клиенты';
  }
}

String _segmentLabel(String segment) {
  switch (segment) {
    case 'VIP':
      return '💎 VIP';
    case 'FREQUENT':
      return '🟢 Частый';
    case 'RARE':
      return '🔴 Редкий';
    case 'LOST':
      return '⚠️ Пропал';
    case 'DEBT':
      return '🟠 Должник';
    case 'REGULAR':
    default:
      return '🟡 Обычный';
  }
}

Color _segmentColor(String segment) {
  switch (segment) {
    case 'VIP':
      return const Color(0xFFEDE9FE);
    case 'FREQUENT':
      return const Color(0xFFDCFCE7);
    case 'RARE':
      return const Color(0xFFFEE2E2);
    case 'LOST':
      return const Color(0xFFFFEDD5);
    case 'DEBT':
      return const Color(0xFFFEF3C7);
    case 'REGULAR':
    default:
      return const Color(0xFFEFF6FF);
  }
}

String _frequencyLabel({required int visits, required int daysSinceLastVisit}) {
  if (visits <= 0) return 'Визитов нет';
  if (visits == 1) return 'Разовый клиент';
  if (daysSinceLastVisit <= 7) return 'Раз в неделю';
  if (daysSinceLastVisit <= 31) return 'Раз в месяц';
  if (daysSinceLastVisit <= 90) return 'Редко';
  return 'Давно не был';
}

String _percentLabel(int value, int total) {
  if (total <= 0) return '0%';
  return '${((value / total) * 100).round()}%';
}
