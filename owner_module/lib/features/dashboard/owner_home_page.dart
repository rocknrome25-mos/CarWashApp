import 'package:flutter/material.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _index = 0;

  final _pages = const [
    _DashboardTab(),
    _OperationsTab(),
    _FinanceTab(),
    _AnalyticsTab(),
    _SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Мойка',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Финансы',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Аналитика',
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

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Owner Dashboard', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Полный контроль мойки в одном месте',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          child: Icon(Icons.location_on_outlined),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Основная локация',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Бульвар Андрея Тарковского, 10',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionTitle('Ключевые показатели'),
                const SizedBox(height: 12),

                const Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Выручка сегодня',
                        value: '₽ 84 500',
                        hint: '+12% к вчера',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Машин сегодня',
                        value: '27',
                        hint: '3 в работе',
                        icon: Icons.directions_car_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Средний чек',
                        value: '₽ 3 130',
                        hint: 'Стабильно',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _KpiCard(
                        title: 'Активная смена',
                        value: 'Открыта',
                        hint: 'Мойка работает',
                        icon: Icons.storefront_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const _SectionTitle('Быстрые действия'),
                const SizedBox(height: 12),

                const Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: 'Операции мойки',
                        subtitle: 'Смена, посты, состояние',
                        icon: Icons.store_mall_directory_outlined,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        title: 'Финансы',
                        subtitle: 'Касса, выручка, оплата',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: 'Клиенты',
                        subtitle: 'Активность и база клиентов',
                        icon: Icons.people_outline,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        title: 'Аналитика',
                        subtitle: 'Тренды и загрузка',
                        icon: Icons.bar_chart_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const _SectionTitle('Состояние мойки'),
                const SizedBox(height: 12),

                const _WashStatusCard(
                  title: 'Текущий статус',
                  status: 'Открыта',
                  revenue: '₽ 84 500',
                  cars: '27 машин',
                  load: 'Загрузка 78%',
                ),

                const SizedBox(height: 24),
                const _SectionTitle('Сводка'),
                const SizedBox(height: 12),

                const _SummaryCard(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OperationsTab extends StatelessWidget {
  const _OperationsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Мойка'),
    );
  }
}

class _FinanceTab extends StatelessWidget {
  const _FinanceTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Финансы'),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Аналитика'),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Настройки'),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 112,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _WashStatusCard extends StatelessWidget {
  final String title;
  final String status;
  final String revenue;
  final String cars;
  final String load;

  const _WashStatusCard({
    required this.title,
    required this.status,
    required this.revenue,
    required this.cars,
    required this.load,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'Открыта';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  isOpen ? const Color(0xFFE8F7EE) : const Color(0xFFF3F4F6),
              child: Icon(
                isOpen ? Icons.storefront : Icons.store_mall_directory_outlined,
                color: isOpen ? const Color(0xFF15803D) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(status, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    '$revenue  •  $cars  •  $load',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow(context, 'Выручка за неделю', '₽ 512 400'),
            const SizedBox(height: 12),
            _summaryRow(context, 'Машин за неделю', '168'),
            const SizedBox(height: 12),
            _summaryRow(context, 'Средняя загрузка', '71%'),
            const SizedBox(height: 12),
            _summaryRow(context, 'Новых клиентов', '23'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}