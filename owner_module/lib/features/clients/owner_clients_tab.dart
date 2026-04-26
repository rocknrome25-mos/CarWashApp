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

  late Future<Map<String, dynamic>> _future;
  Timer? _searchDebounce;

  String _period = 'month';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() {
    return _api.getOwnerClients(period: _period, q: _query, limit: 100);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _changePeriod(String value) {
    if (_period == value) return;
    setState(() {
      _period = value;
      _future = _load();
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

          final clients = _list(data['clients']);
          final topClients = _list(data['topClients']);
          final recentVisits = _list(data['recentVisits'] ?? data['gallery']);
          final byGender = _list(analytics['byGender']);
          final byBodyType = _list(analytics['byBodyType']);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
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
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск: имя, телефон, номер авто',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _future = _load();
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: _onSearchChanged,
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
                      title: 'Повторные',
                      value: '${_asInt(totals['returnedClients'])}',
                      subtitle: 'Больше 1 визита',
                      icon: Icons.repeat,
                    ),
                    _MetricTile(
                      title: 'Заблокированы',
                      value: '${_asInt(totals['blockedClients'])}',
                      subtitle: 'Проблемные',
                      icon: Icons.block,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (topClients.isNotEmpty) ...[
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
                  const SizedBox(height: 24),
                ],
                if (recentVisits.isNotEmpty) ...[
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
                        return _RecentVisitCard(visit: recentVisits[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (byGender.isNotEmpty || byBodyType.isNotEmpty) ...[
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
                  const SizedBox(height: 24),
                ],
                _SectionHeader(
                  title: 'Все клиенты',
                  subtitle: clients.isEmpty
                      ? 'Клиентов по текущему фильтру нет'
                      : 'Нажмите на клиента, чтобы открыть детальную карточку',
                ),
                const SizedBox(height: 12),
                if (clients.isEmpty)
                  const _EmptyCard(text: 'Клиенты не найдены')
                else
                  ...clients.map(
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
    setState(() {
      _future = _load();
    });
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
          final client = _map(data['client']);
          final totals = _map(client['totals']);
          final paymentMethods = _map(client['paymentMethods']);
          final cars = _list(client['cars']);
          final visits = _list(client['visits']);

          final isBlocked = client['isBlocked'] == true;
          final name = (client['name'] ?? 'Без имени').toString();
          final phone = (client['phone'] ?? '').toString();

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
                      value: _rub(_asInt(totals['totalSpent'])),
                      subtitle: 'Все оплаты',
                      icon: Icons.payments_outlined,
                    ),
                    _MetricTile(
                      title: 'За период',
                      value: _rub(_asInt(totals['periodSpent'])),
                      subtitle: _periodLabel(widget.period),
                      icon: Icons.trending_up,
                    ),
                    _MetricTile(
                      title: 'Визиты',
                      value: '${_asInt(totals['visits'])}',
                      subtitle: 'Завершённые',
                      icon: Icons.local_car_wash_outlined,
                    ),
                    _MetricTile(
                      title: 'Средний чек',
                      value: _rub(_asInt(totals['averageCheck'])),
                      subtitle: 'По визитам',
                      icon: Icons.receipt_long_outlined,
                    ),
                    _MetricTile(
                      title: 'Контракт / долг',
                      value: _rub(_asInt(totals['contractDebtRub'])),
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
                  ...cars.map((car) => _CarCard(car: car)),
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
                  if (isBlocked)
                    const _SmallChip(
                      text: 'Блок',
                      background: Color(0xFFFEE2E2),
                    ),
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
                    text: 'Период: ${_rub(_asInt(client['periodSpent']))}',
                  ),
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
        title: Text((client['name'] ?? 'Без имени').toString()),
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

  const _RecentVisitCard({required this.visit});

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
                  Text(
                    _formatDateTime(visit['finishedAt'] ?? visit['dateTime']),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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

  const _CarCard({required this.car});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEFF6FF),
          child: Icon(Icons.directions_car_outlined, color: Color(0xFF2563EB)),
        ),
        title: Text((car['plate'] ?? 'Номер не указан').toString()),
        subtitle: Text(
          '${car['make'] ?? ''} ${car['model'] ?? ''} • ${car['bodyType'] ?? 'кузов не указан'}',
        ),
        trailing: Text(
          (car['year'] ?? '').toString(),
          style: theme.textTheme.bodySmall,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _PaymentMethodTile(
                title: 'Наличные',
                value: _rub(_asInt(methods['cash'])),
                icon: Icons.payments_outlined,
              ),
            ),
            Expanded(
              child: _PaymentMethodTile(
                title: 'Карта',
                value: _rub(_asInt(methods['card'])),
                icon: Icons.credit_card,
              ),
            ),
            Expanded(
              child: _PaymentMethodTile(
                title: 'Контракт',
                value: _rub(_asInt(methods['contract'])),
                icon: Icons.description_outlined,
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
  final IconData icon;

  const _PaymentMethodTile({
    required this.title,
    required this.value,
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
  return ((value as List?) ?? const [])
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
