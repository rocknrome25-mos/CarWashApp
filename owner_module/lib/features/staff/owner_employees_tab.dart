import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class OwnerEmployeesTab extends StatefulWidget {
  const OwnerEmployeesTab({super.key});

  @override
  State<OwnerEmployeesTab> createState() => _OwnerEmployeesTabState();
}

class _OwnerEmployeesTabState extends State<OwnerEmployeesTab> {
  late Future<_EmployeesScreenData> _future;
  String _period = 'month';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_EmployeesScreenData> _loadData() async {
    final analyticsUri = Uri.parse(
      '${AppConfig.defaultBaseUrl}/owner/employees/analytics?period=$_period',
    );
    final employeesUri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/employees');

    final responses = await Future.wait([
      http.get(analyticsUri).timeout(const Duration(seconds: 20)),
      http.get(employeesUri).timeout(const Duration(seconds: 20)),
    ]);

    final analyticsResponse = responses[0];
    final employeesResponse = responses[1];

    if (analyticsResponse.statusCode < 200 ||
        analyticsResponse.statusCode >= 300) {
      throw Exception(
        'Employees analytics request failed: ${analyticsResponse.statusCode}',
      );
    }

    if (employeesResponse.statusCode < 200 ||
        employeesResponse.statusCode >= 300) {
      throw Exception(
        'Employees request failed: ${employeesResponse.statusCode}',
      );
    }

    final analyticsDecoded = jsonDecode(analyticsResponse.body);
    final employeesDecoded = jsonDecode(employeesResponse.body);

    if (analyticsDecoded is! Map<String, dynamic>) {
      throw Exception('Employees analytics response is invalid');
    }
    if (employeesDecoded is! Map<String, dynamic>) {
      throw Exception('Employees response is invalid');
    }

    return _EmployeesScreenData.fromJson(
      analyticsDecoded,
      employeesJson: employeesDecoded,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  void _changePeriod(String value) {
    if (_period == value) return;
    setState(() {
      _period = value;
      _future = _loadData();
    });
  }

  Future<void> _openCreateDialog() async {
    if (_isBusy) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateEmployeeDialog(),
    );

    if (!mounted) return;

    if (created == true) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сотрудник создан')));
    }
  }

  Future<void> _toggleEmployee(String id, bool isActive) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.defaultBaseUrl}/owner/employees/$id/toggle',
      );
      final response = await http.post(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }

      await _reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive ? 'Сотрудник отключён' : 'Сотрудник активирован',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _openEditDialog(_EmployeeView employee) async {
    if (_isBusy) return;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditEmployeeDialog(employee: employee),
    );

    if (!mounted) return;

    if (updated == true) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сотрудник обновлён')));
    }
  }

  Future<void> _openResetPasswordDialog(_EmployeeView employee) async {
    if (_isBusy) return;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetPasswordDialog(employee: employee),
    );

    if (!mounted) return;

    if (updated == true) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароль сброшен')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          FutureBuilder<_EmployeesScreenData>(
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

              final data = snapshot.data!;

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Сотрудники',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isBusy ? null : _openCreateDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Детализация по сотрудникам и администраторам',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            title: 'Сотрудников',
                            value: '${data.totalEmployees}',
                            subtitle:
                                'Админов: ${data.totalAdmins} • Мойщиков: ${data.totalWashers}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            title: 'Локация',
                            value: data.locationName,
                            subtitle: 'Период: ${_periodLabel(_period)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'day', label: Text('День')),
                          ButtonSegment(value: 'month', label: Text('Месяц')),
                          ButtonSegment(value: 'year', label: Text('Год')),
                        ],
                        selected: {_period},
                        onSelectionChanged: (value) {
                          _changePeriod(value.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Администраторы', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (data.admins.isEmpty)
                      const _EmptyBlock(text: 'Нет администраторов')
                    else
                      ...data.admins.map(
                        (e) => _EmployeeCard(
                          employee: e,
                          onEdit: () => _openEditDialog(e),
                          onToggle: () => _toggleEmployee(e.id, e.isActive),
                          onResetPassword: () => _openResetPasswordDialog(e),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text('Мойщики', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (data.washers.isEmpty)
                      const _EmptyBlock(text: 'Нет мойщиков')
                    else
                      ...data.washers.map(
                        (e) => _EmployeeCard(
                          employee: e,
                          onEdit: () => _openEditDialog(e),
                          onToggle: () => _toggleEmployee(e.id, e.isActive),
                          onResetPassword: () => _openResetPasswordDialog(e),
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

  String _periodLabel(String period) {
    switch (period) {
      case 'day':
        return 'день';
      case 'year':
        return 'год';
      case 'month':
      default:
        return 'месяц';
    }
  }
}

class _EmployeesScreenData {
  final String locationName;
  final int totalEmployees;
  final int totalAdmins;
  final int totalWashers;
  final List<_EmployeeView> admins;
  final List<_EmployeeView> washers;

  const _EmployeesScreenData({
    required this.locationName,
    required this.totalEmployees,
    required this.totalAdmins,
    required this.totalWashers,
    required this.admins,
    required this.washers,
  });

  factory _EmployeesScreenData.fromJson(
    Map<String, dynamic> analyticsJson, {
    required Map<String, dynamic> employeesJson,
  }) {
    final location = Map<String, dynamic>.from(
      (analyticsJson['location'] as Map?) ?? const {},
    );
    final totals = Map<String, dynamic>.from(
      (analyticsJson['totals'] as Map?) ?? const {},
    );

    final employeeIndex = <String, Map<String, dynamic>>{};
    for (final bucket in ['admins', 'washers']) {
      final list = ((employeesJson[bucket] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e));
      for (final item in list) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty) {
          employeeIndex[id] = item;
        }
      }
    }

    List<_EmployeeView> parseList(String key) {
      return ((analyticsJson[key] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map((item) {
            final id = (item['id'] ?? '').toString();
            final base = employeeIndex[id] ?? const <String, dynamic>{};
            return _EmployeeView.fromJson(item, base: base);
          })
          .toList();
    }

    return _EmployeesScreenData(
      locationName: (location['name'] ?? 'Локация').toString(),
      totalEmployees: _asInt(totals['employees']),
      totalAdmins: _asInt(totals['admins']),
      totalWashers: _asInt(totals['washers']),
      admins: parseList('admins'),
      washers: parseList('washers'),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class _EmployeeView {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isActive;
  final bool mustChangePassword;
  final String lastLoginAt;
  final int shiftsOpened;
  final int bookingsHandled;
  final int discountsGiven;
  final int suspiciousActions;
  final int carsServiced;
  final int salesRevenueRub;
  final int earnedRub;

  const _EmployeeView({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.lastLoginAt,
    required this.shiftsOpened,
    required this.bookingsHandled,
    required this.discountsGiven,
    required this.suspiciousActions,
    required this.carsServiced,
    required this.salesRevenueRub,
    required this.earnedRub,
  });

  factory _EmployeeView.fromJson(
    Map<String, dynamic> json, {
    required Map<String, dynamic> base,
  }) {
    final stats = Map<String, dynamic>.from(
      (json['stats'] as Map?) ?? const {},
    );

    return _EmployeeView(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Без имени').toString(),
      phone: (json['phone'] ?? base['phone'] ?? '').toString(),
      role: (json['role'] ?? base['role'] ?? '').toString(),
      isActive: (base['isActive'] ?? json['isActive']) == true,
      mustChangePassword: base['mustChangePassword'] == true,
      lastLoginAt: (json['lastLoginAt'] ?? base['lastLoginAt'] ?? '')
          .toString(),
      shiftsOpened: _asInt(stats['shiftsOpened']),
      bookingsHandled: _asInt(stats['bookingsHandled']),
      discountsGiven: _asInt(stats['discountsGiven']),
      suspiciousActions: _asInt(stats['suspiciousActions']),
      carsServiced: _asInt(stats['carsServiced']),
      salesRevenueRub: _asInt(stats['salesRevenueRub']),
      earnedRub: _asInt(stats['earnedRub']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String get roleLabel {
    switch (role) {
      case 'ADMIN':
        return 'Администратор';
      case 'WASHER':
        return 'Мойщик';
      default:
        return role;
    }
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isWasher => role == 'WASHER';
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _MetricTile({
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

class _EmployeeCard extends StatelessWidget {
  final _EmployeeView employee;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onResetPassword;

  const _EmployeeCard({
    required this.employee,
    required this.onEdit,
    required this.onToggle,
    required this.onResetPassword,
  });

  String _rub(int value) => '₽ $value';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF3F4F6),
                  child: Icon(
                    employee.isAdmin
                        ? Icons.badge_outlined
                        : Icons.cleaning_services_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${employee.roleLabel}${employee.phone.isNotEmpty ? ' • ${employee.phone}' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      if (employee.mustChangePassword) ...[
                        const SizedBox(height: 8),
                        _InlineChip(
                          text: 'Требуется смена пароля',
                          background: const Color(0xFFFEF3C7),
                          foreground: const Color(0xFF92400E),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(
                      text: employee.isActive ? 'Активен' : 'Отключён',
                      background: employee.isActive
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                    ),
                    const SizedBox(height: 10),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'toggle') {
                          onToggle();
                        } else if (value == 'reset') {
                          onResetPassword();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            employee.isActive ? 'Отключить' : 'Активировать',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'reset',
                          child: Text('Сбросить пароль'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Действия',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (employee.isAdmin) ...[
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'Смен открыл',
                      value: '${employee.shiftsOpened}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      title: 'Бронирований',
                      value: '${employee.bookingsHandled}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'Скидок дал',
                      value: '${employee.discountsGiven}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      title: 'Подозрительных',
                      value: '${employee.suspiciousActions}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'Принёс дохода',
                      value: _rub(employee.salesRevenueRub),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      title: 'Заработал',
                      value: _rub(employee.earnedRub),
                    ),
                  ),
                ],
              ),
            ] else if (employee.isWasher) ...[
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'Смен отработал',
                      value: '${employee.shiftsOpened}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      title: 'Машин обслужил',
                      value: '${employee.carsServiced}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      title: 'Заработал',
                      value: _rub(employee.earnedRub),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
            if (employee.lastLoginAt.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Последний вход: ${_formatDateTime(employee.lastLoginAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;

  const _MiniStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color background;

  const _StatusPill({required this.text, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _InlineChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _InlineChip({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
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

class _CreateEmployeeDialog extends StatefulWidget {
  const _CreateEmployeeDialog();

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = 'ADMIN';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final uri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/employees');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'role': _role,
              'password': _passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый сотрудник'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Введите имя';
                  if (v.length < 2) return 'Слишком короткое имя';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Телефон'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Введите телефон';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Роль'),
                items: const [
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text('Администратор'),
                  ),
                  DropdownMenuItem(value: 'WASHER', child: Text('Мойщик')),
                ],
                onChanged: (value) {
                  setState(() {
                    _role = value ?? 'ADMIN';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Введите пароль';
                  if (v.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }
}

class _EditEmployeeDialog extends StatefulWidget {
  final _EmployeeView employee;

  const _EditEmployeeDialog({required this.employee});

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee.name);
    _phoneController = TextEditingController(text: widget.employee.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.defaultBaseUrl}/owner/employees/${widget.employee.id}',
      );
      final response = await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать сотрудника'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Введите имя';
                  if (v.length < 2) return 'Слишком короткое имя';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Телефон'),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Введите телефон';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final _EmployeeView employee;

  const _ResetPasswordDialog({required this.employee});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.defaultBaseUrl}/owner/employees/${widget.employee.id}/reset-password',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': _passwordController.text.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сбросить пароль'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Новый пароль'),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Введите пароль';
              if (v.length < 6) return 'Минимум 6 символов';
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сбросить'),
        ),
      ],
    );
  }
}

String _extractErrorMessage(String body, int statusCode) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join(', ');
      }
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) {
        return '$error ($statusCode)';
      }
    }
  } catch (_) {
    // ignore
  }

  return 'HTTP $statusCode';
}

String _formatDateTime(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;

  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day.$month.$year $hour:$minute';
}