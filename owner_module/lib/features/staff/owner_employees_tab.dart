import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'widgets/create_employee_dialog.dart';
import 'widgets/owner_employee_card.dart';

class OwnerEmployeesTab extends StatefulWidget {
  const OwnerEmployeesTab({super.key});

  @override
  State<OwnerEmployeesTab> createState() => _OwnerEmployeesTabState();
}

class _OwnerEmployeesTabState extends State<OwnerEmployeesTab> {
  late Future<Map<String, dynamic>> _future;
  bool _isBusy = false;

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

  Future<void> _reload() async {
    setState(() {
      _future = _loadEmployees();
    });
    await _future;
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateEmployeeDialog(),
    );

    if (!mounted) return;

    if (created == true) {
      await _runBusyAction(() async {
        await _reload();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сотрудник создан')));
    }
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          FutureBuilder<Map<String, dynamic>>(
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
                          style: theme.textTheme.bodyMedium,
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

              final data = snapshot.data ?? <String, dynamic>{};
              final totals = Map<String, dynamic>.from(
                (data['totals'] as Map?) ?? const {},
              );
              final admins = ((data['admins'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              final washers = ((data['washers'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

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
                                'Сотрудники',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Администраторы и мойщики по текущей локации',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isBusy ? null : _openCreateDialog,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StaffInfoTile(
                            title: 'Всего',
                            value: '${_intValue(totals['all'])}',
                            subtitle: 'Сотрудников',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StaffInfoTile(
                            title: 'Админы',
                            value: '${_intValue(totals['admins'])}',
                            subtitle: 'Человек',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StaffInfoTile(
                            title: 'Мойщики',
                            value: '${_intValue(totals['washers'])}',
                            subtitle: 'Человек',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StaffInfoTile(
                            title: 'Активные',
                            value: '${_intValue(totals['active'])}',
                            subtitle: 'Работают',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Администраторы', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (admins.isEmpty)
                      const _EmptyBlock(text: 'Нет администраторов')
                    else
                      ...admins.map(
                        (e) => OwnerEmployeeCard(
                          data: e,
                          onUpdated: () async {
                            await _runBusyAction(() async {
                              await _reload();
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('Мойщики', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (washers.isEmpty)
                      const _EmptyBlock(text: 'Нет мойщиков')
                    else
                      ...washers.map(
                        (e) => OwnerEmployeeCard(
                          data: e,
                          onUpdated: () async {
                            await _runBusyAction(() async {
                              await _reload();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_isBusy)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffInfoTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _StaffInfoTile({
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

class _EmptyBlock extends StatelessWidget {
  final String text;

  const _EmptyBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    );
  }
}
