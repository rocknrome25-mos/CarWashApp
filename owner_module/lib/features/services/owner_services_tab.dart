import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class OwnerServicesTab extends StatefulWidget {
  const OwnerServicesTab({super.key});

  @override
  State<OwnerServicesTab> createState() => _OwnerServicesTabState();
}

class _OwnerServicesTabState extends State<OwnerServicesTab> {
  late Future<_ServicesScreenData> _future;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ServicesScreenData> _loadData() async {
    final summaryUri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/summary');
    final summaryResponse = await http
        .get(summaryUri)
        .timeout(const Duration(seconds: 20));

    if (summaryResponse.statusCode < 200 || summaryResponse.statusCode >= 300) {
      throw Exception('Summary request failed: ${summaryResponse.statusCode}');
    }

    final summaryDecoded = jsonDecode(summaryResponse.body);
    if (summaryDecoded is! Map<String, dynamic>) {
      throw Exception('Summary response is not an object');
    }

    final location = Map<String, dynamic>.from(
      (summaryDecoded['location'] as Map?) ?? {},
    );
    final locationId = (location['id'] ?? '').toString().trim();
    final locationName = (location['name'] ?? 'Локация').toString().trim();

    if (locationId.isEmpty) {
      throw Exception('Location id is missing in owner summary');
    }

    final servicesUri = Uri.parse(
      '${AppConfig.defaultBaseUrl}/services'
      '?locationId=$locationId&includeInactive=true',
    );

    final servicesResponse = await http
        .get(servicesUri)
        .timeout(const Duration(seconds: 20));

    if (servicesResponse.statusCode < 200 ||
        servicesResponse.statusCode >= 300) {
      throw Exception(
        'Services request failed: ${servicesResponse.statusCode}',
      );
    }

    final servicesDecoded = jsonDecode(servicesResponse.body);
    if (servicesDecoded is! List) {
      throw Exception('Services response is not a list');
    }

    final services = servicesDecoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return _ServicesScreenData(
      locationId: locationId,
      locationName: locationName.isEmpty ? 'Локация' : locationName,
      services: services,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _toggleService(Map<String, dynamic> service) async {
    if (_isBusy) return;

    final serviceId = (service['id'] ?? '').toString();
    final serviceName = (service['name'] ?? 'Сервис').toString();
    final isActive = service['isActive'] == true;

    if (serviceId.isEmpty) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.defaultBaseUrl}/owner/services/$serviceId/toggle',
      );

      final response = await http
          .post(uri)
          .timeout(const Duration(seconds: 20));

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
            isActive
                ? 'Сервис "$serviceName" отключён'
                : 'Сервис "$serviceName" активирован',
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

  Future<void> _openCreateDialog(List<Map<String, dynamic>> services) async {
    if (_isBusy) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateServiceDialog(allServices: services),
    );

    if (!mounted) return;

    if (created == true) {
      await _reload();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сервис создан')));
    }
  }

  Future<void> _openEditDialog(
    Map<String, dynamic> service,
    List<Map<String, dynamic>> services,
  ) async {
    if (_isBusy) return;

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _EditServiceDialog(service: service, allServices: services),
    );

    if (!mounted) return;

    if (updated == true) {
      await _reload();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сервис обновлён')));
    }
  }

  List<Map<String, dynamic>> _sortServices(List<Map<String, dynamic>> items) {
    final list = [...items];
    list.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().toLowerCase();
      final nameB = (b['name'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    return list;
  }

  // ignore: unused_element
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
          FutureBuilder<_ServicesScreenData>(
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

              final data = snapshot.data!;
              final services = data.services;

              final baseServices = _sortServices(
                services.where((e) => '${e['kind']}' == 'BASE').toList(),
              );
              final addonServices = _sortServices(
                services.where((e) => '${e['kind']}' == 'ADDON').toList(),
              );

              final activeCount = services
                  .where((e) => e['isActive'] == true)
                  .length;
              final publishedCount = services
                  .where((e) => e['isPublished'] == true)
                  .length;

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
                                'Сервисы',
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Услуги и доп. услуги для локации ${data.locationName}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => _openCreateDialog(services),
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ServiceInfoTile(
                            title: 'Всего',
                            value: '${services.length}',
                            subtitle: 'Сервисов',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServiceInfoTile(
                            title: 'Активные',
                            value: '$activeCount',
                            subtitle: 'Видны в системе',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ServiceInfoTile(
                            title: 'Опубликованы',
                            value: '$publishedCount',
                            subtitle: 'Готовы для клиента',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ServiceInfoTile(
                            title: 'Базовые / доп.',
                            value:
                                '${baseServices.length}/${addonServices.length}',
                            subtitle: 'Структура услуг',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Базовые услуги', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (baseServices.isEmpty)
                      const _EmptyBlock(text: 'Нет базовых услуг')
                    else
                      ...baseServices.map(
                        (service) => OwnerServiceCard(
                          data: service,
                          isBusy: _isBusy,
                          onToggle: () => _toggleService(service),
                          onEdit: () => _openEditDialog(service, services),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Дополнительные услуги',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (addonServices.isEmpty)
                      const _EmptyBlock(text: 'Нет дополнительных услуг')
                    else
                      ...addonServices.map(
                        (service) => OwnerServiceCard(
                          data: service,
                          isBusy: _isBusy,
                          onToggle: () => _toggleService(service),
                          onEdit: () => _openEditDialog(service, services),
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

class _ServicesScreenData {
  final String locationId;
  final String locationName;
  final List<Map<String, dynamic>> services;

  const _ServicesScreenData({
    required this.locationId,
    required this.locationName,
    required this.services,
  });
}

class OwnerServiceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final bool isBusy;

  const OwnerServiceCard({
    super.key,
    required this.data,
    required this.onToggle,
    required this.onEdit,
    required this.isBusy,
  });

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _kindLabel(String raw) {
    switch (raw) {
      case 'BASE':
        return 'Базовая услуга';
      case 'ADDON':
        return 'Доп. услуга';
      default:
        return raw;
    }
  }

  IconData _imageIcon(String raw) {
    switch (raw) {
      case 'FULL_WASH':
        return Icons.auto_awesome;
      case 'WAX':
        return Icons.shield_outlined;
      case 'TIRES':
        return Icons.tire_repair_outlined;
      case 'INTERIOR':
        return Icons.chair_outlined;
      case 'LEATHER_CARE':
        return Icons.checkroom_outlined;
      case 'EXTERIOR_WASH':
      default:
        return Icons.local_car_wash_outlined;
    }
  }

  String _imageLabel(String raw) {
    switch (raw) {
      case 'FULL_WASH':
        return 'Комплекс';
      case 'WAX':
        return 'Воск';
      case 'TIRES':
        return 'Шины';
      case 'INTERIOR':
        return 'Салон';
      case 'LEATHER_CARE':
        return 'Кожа';
      case 'EXTERIOR_WASH':
      default:
        return 'Кузов';
    }
  }

  String _priceLabel() {
    final hasBodyTypePricing = data['hasBodyTypePricing'] == true;
    final priceRub = _intValue(data['priceRub']);

    final prices = ((data['bodyTypePrices'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (!hasBodyTypePricing || prices.isEmpty) {
      return '₽ $priceRub';
    }

    final values = prices
        .map((e) {
          final v = e['priceRub'];
          if (v is int) return v;
          if (v is num) return v.toInt();
          return null;
        })
        .whereType<int>()
        .toList();

    if (values.isEmpty) {
      return '₽ $priceRub';
    }

    values.sort();
    return values.first == values.last
        ? '₽ ${values.first}'
        : 'от ₽ ${values.first}';
  }

  String _bodyTypePricingLabel() {
    final hasBodyTypePricing = data['hasBodyTypePricing'] == true;
    final prices = ((data['bodyTypePrices'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (!hasBodyTypePricing || prices.isEmpty) {
      return '';
    }

    return prices
        .map((e) => '${e['bodyType'] ?? ''}: ₽ ${e['priceRub'] ?? 0}')
        .join(' · ');
  }

  String _includedAddonsLabel() {
    final items = ((data['includedAddonsForBase'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (items.isEmpty) return '';

    final names = items
        .map((e) {
          final addon = Map<String, dynamic>.from(
            (e['addonService'] as Map?) ?? const {},
          );
          return (addon['name'] ?? '').toString().trim();
        })
        .where((e) => e.isNotEmpty)
        .toList();

    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = (data['name'] ?? 'Без названия').toString();
    final description = (data['description'] ?? '').toString().trim();
    final kind = (data['kind'] ?? '').toString();
    final durationMin = _intValue(data['durationMin']);
    final isActive = data['isActive'] == true;
    final isPublished = data['isPublished'] == true;
    final imageKey = (data['imageKey'] ?? 'EXTERIOR_WASH').toString();

    final bodyTypePricingLabel = _bodyTypePricingLabel();
    final includedAddons = _includedAddonsLabel();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_imageIcon(imageKey), size: 26),
                  const SizedBox(height: 4),
                  Text(
                    _imageLabel(imageKey),
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  if (description.isNotEmpty) const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChipLabel(
                        text: _kindLabel(kind),
                        background: const Color(0xFFEFF6FF),
                        foreground: const Color(0xFF1D4ED8),
                      ),
                      _ChipLabel(
                        text: _priceLabel(),
                        background: const Color(0xFFF0FDF4),
                        foreground: const Color(0xFF15803D),
                      ),
                      _ChipLabel(
                        text: '$durationMin мин',
                        background: const Color(0xFFFFF7ED),
                        foreground: const Color(0xFF9A3412),
                        icon: Icons.schedule_outlined,
                      ),
                      _ChipLabel(
                        text: isPublished ? 'Опубликовано' : 'Черновик',
                        background: isPublished
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF3C7),
                        foreground: isPublished
                            ? const Color(0xFF047857)
                            : const Color(0xFF92400E),
                      ),
                    ],
                  ),
                  if (bodyTypePricingLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      bodyTypePricingLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                  if (includedAddons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Включает: $includedAddons',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                const SizedBox(height: 10),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'toggle') {
                      onToggle();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Редактировать'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(isActive ? 'Отключить' : 'Включить'),
                    ),
                  ],
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : null,
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('Действия'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateServiceDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allServices;

  const _CreateServiceDialog({required this.allServices});

  @override
  State<_CreateServiceDialog> createState() => _CreateServiceDialogState();
}

class _CreateServiceDialogState extends State<_CreateServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();

  bool _submitting = false;
  String _kind = 'BASE';
  String _imageKey = 'EXTERIOR_WASH';
  bool _isPublished = true;
  bool _hasBodyTypePricing = false;

  final Map<String, TextEditingController> _bodyTypeControllers = {
    'Седан': TextEditingController(),
    'Кроссовер': TextEditingController(),
    'Внедорожник': TextEditingController(),
    'Минивэн': TextEditingController(),
  };

  final Set<String> _includedAddonIds = {};

  List<Map<String, dynamic>> get _addonServices => widget.allServices
      .where((e) => '${e['kind']}' == 'ADDON')
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    for (final controller in _bodyTypeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'kind': _kind,
        'imageKey': _imageKey,
        'priceRub': int.parse(_priceController.text.trim()),
        'durationMin': int.parse(_durationController.text.trim()),
        'isPublished': _isPublished,
        'hasBodyTypePricing': _hasBodyTypePricing,
      };

      if (_hasBodyTypePricing) {
        body['bodyTypePrices'] = _bodyTypeControllers.entries
            .where((e) => e.value.text.trim().isNotEmpty)
            .map(
              (e) => {
                'bodyType': e.key,
                'priceRub': int.parse(e.value.text.trim()),
              },
            )
            .toList();
      }

      if (_kind == 'BASE' && _includedAddonIds.isNotEmpty) {
        body['includedAddonIds'] = _includedAddonIds.toList();
      }

      final uri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/services');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
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
      title: const Text('Новый сервис'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Введите название';
                    if (v.length < 2) return 'Слишком короткое название';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Описание услуги',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Тип сервиса'),
                  items: const [
                    DropdownMenuItem(
                      value: 'BASE',
                      child: Text('Базовая услуга'),
                    ),
                    DropdownMenuItem(
                      value: 'ADDON',
                      child: Text('Доп. услуга'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _kind = value ?? 'BASE';
                      if (_kind != 'BASE') {
                        _includedAddonIds.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _imageKey,
                  decoration: const InputDecoration(labelText: 'Иконка услуги'),
                  items: const [
                    DropdownMenuItem(
                      value: 'EXTERIOR_WASH',
                      child: Text('Exterior wash'),
                    ),
                    DropdownMenuItem(
                      value: 'FULL_WASH',
                      child: Text('Full wash'),
                    ),
                    DropdownMenuItem(value: 'WAX', child: Text('Wax')),
                    DropdownMenuItem(value: 'TIRES', child: Text('Tires')),
                    DropdownMenuItem(
                      value: 'INTERIOR',
                      child: Text('Interior'),
                    ),
                    DropdownMenuItem(
                      value: 'LEATHER_CARE',
                      child: Text('Leather care'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _imageKey = value ?? 'EXTERIOR_WASH';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Базовая цена, ₽',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Введите цену';
                    final n = int.tryParse(v);
                    if (n == null) return 'Введите число';
                    if (n < 0) return 'Цена не может быть отрицательной';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Длительность, мин',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Введите длительность';
                    final n = int.tryParse(v);
                    if (n == null) return 'Введите число';
                    if (n <= 0) return 'Должно быть больше 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Опубликовать сразу'),
                  value: _isPublished,
                  onChanged: (value) {
                    setState(() {
                      _isPublished = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Цена зависит от типа кузова'),
                  value: _hasBodyTypePricing,
                  onChanged: (value) {
                    setState(() {
                      _hasBodyTypePricing = value;
                    });
                  },
                ),
                if (_hasBodyTypePricing) ...[
                  const SizedBox(height: 4),
                  ..._bodyTypeControllers.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '${entry.key}, ₽',
                        ),
                        validator: (value) {
                          if (!_hasBodyTypePricing) return null;
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return null;
                          if (int.tryParse(v) == null) return 'Введите число';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
                if (_kind == 'BASE' && _addonServices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Что входит в услугу',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._addonServices.map((service) {
                    final id = (service['id'] ?? '').toString();
                    final name = (service['name'] ?? 'Add-on').toString();
                    final selected = _includedAddonIds.contains(id);

                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _includedAddonIds.add(id);
                          } else {
                            _includedAddonIds.remove(id);
                          }
                        });
                      },
                    );
                  }),
                ],
              ],
            ),
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

class _EditServiceDialog extends StatefulWidget {
  final Map<String, dynamic> service;
  final List<Map<String, dynamic>> allServices;

  const _EditServiceDialog({required this.service, required this.allServices});

  @override
  State<_EditServiceDialog> createState() => _EditServiceDialogState();
}

class _EditServiceDialogState extends State<_EditServiceDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;

  bool _submitting = false;
  late String _imageKey;
  late bool _isPublished;
  late bool _hasBodyTypePricing;

  final Map<String, TextEditingController> _bodyTypeControllers = {
    'Седан': TextEditingController(),
    'Кроссовер': TextEditingController(),
    'Внедорожник': TextEditingController(),
    'Минивэн': TextEditingController(),
  };

  final Set<String> _includedAddonIds = {};

  List<Map<String, dynamic>> get _addonServices => widget.allServices
      .where((e) => '${e['kind']}' == 'ADDON')
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: (widget.service['name'] ?? '').toString(),
    );
    _descriptionController = TextEditingController(
      text: (widget.service['description'] ?? '').toString(),
    );
    _priceController = TextEditingController(
      text: '${_asInt(widget.service['priceRub'])}',
    );
    _durationController = TextEditingController(
      text: '${_asInt(widget.service['durationMin'])}',
    );
    _imageKey = (widget.service['imageKey'] ?? 'EXTERIOR_WASH').toString();
    _isPublished = widget.service['isPublished'] == true;
    _hasBodyTypePricing = widget.service['hasBodyTypePricing'] == true;

    final bodyTypePrices =
        ((widget.service['bodyTypePrices'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    for (final item in bodyTypePrices) {
      final bodyType = (item['bodyType'] ?? '').toString();
      final priceRub = _asInt(item['priceRub']);
      if (_bodyTypeControllers.containsKey(bodyType)) {
        _bodyTypeControllers[bodyType]!.text = '$priceRub';
      }
    }

    final includedItems =
        ((widget.service['includedAddonsForBase'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    for (final item in includedItems) {
      final addon = Map<String, dynamic>.from(
        (item['addonService'] as Map?) ?? const {},
      );
      final id = (addon['id'] ?? '').toString();
      if (id.isNotEmpty) {
        _includedAddonIds.add(id);
      }
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    for (final controller in _bodyTypeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final serviceId = (widget.service['id'] ?? '').toString();
    final kind = (widget.service['kind'] ?? '').toString();

    if (serviceId.isEmpty) return;

    setState(() {
      _submitting = true;
    });

    try {
      final body = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageKey': _imageKey,
        'priceRub': int.parse(_priceController.text.trim()),
        'durationMin': int.parse(_durationController.text.trim()),
        'isPublished': _isPublished,
        'hasBodyTypePricing': _hasBodyTypePricing,
      };

      body['bodyTypePrices'] = _hasBodyTypePricing
          ? _bodyTypeControllers.entries
                .where((e) => e.value.text.trim().isNotEmpty)
                .map(
                  (e) => {
                    'bodyType': e.key,
                    'priceRub': int.parse(e.value.text.trim()),
                  },
                )
                .toList()
          : <Map<String, dynamic>>[];

      if (kind == 'BASE') {
        body['includedAddonIds'] = _includedAddonIds.toList();
      }

      final uri = Uri.parse(
        '${AppConfig.defaultBaseUrl}/owner/services/$serviceId',
      );

      final response = await http
          .patch(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
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
    final kind = (widget.service['kind'] ?? '').toString();

    return AlertDialog(
      title: const Text('Редактировать сервис'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Введите название';
                    if (v.length < 2) return 'Слишком короткое название';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Описание услуги',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _imageKey,
                  decoration: const InputDecoration(labelText: 'Иконка услуги'),
                  items: const [
                    DropdownMenuItem(
                      value: 'EXTERIOR_WASH',
                      child: Text('Exterior wash'),
                    ),
                    DropdownMenuItem(
                      value: 'FULL_WASH',
                      child: Text('Full wash'),
                    ),
                    DropdownMenuItem(value: 'WAX', child: Text('Wax')),
                    DropdownMenuItem(value: 'TIRES', child: Text('Tires')),
                    DropdownMenuItem(
                      value: 'INTERIOR',
                      child: Text('Interior'),
                    ),
                    DropdownMenuItem(
                      value: 'LEATHER_CARE',
                      child: Text('Leather care'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _imageKey = value ?? 'EXTERIOR_WASH';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Базовая цена, ₽',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Введите цену';
                    final n = int.tryParse(v);
                    if (n == null) return 'Введите число';
                    if (n < 0) return 'Цена не может быть отрицательной';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Длительность, мин',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Введите длительность';
                    final n = int.tryParse(v);
                    if (n == null) return 'Введите число';
                    if (n <= 0) return 'Должно быть больше 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Опубликовано'),
                  value: _isPublished,
                  onChanged: (value) {
                    setState(() {
                      _isPublished = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Цена зависит от типа кузова'),
                  value: _hasBodyTypePricing,
                  onChanged: (value) {
                    setState(() {
                      _hasBodyTypePricing = value;
                    });
                  },
                ),
                if (_hasBodyTypePricing) ...[
                  const SizedBox(height: 4),
                  ..._bodyTypeControllers.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '${entry.key}, ₽',
                        ),
                        validator: (value) {
                          if (!_hasBodyTypePricing) return null;
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return null;
                          if (int.tryParse(v) == null) return 'Введите число';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
                if (kind == 'BASE' && _addonServices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Что входит в услугу',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._addonServices.map((service) {
                    final id = (service['id'] ?? '').toString();
                    final name = (service['name'] ?? 'Add-on').toString();
                    final selected = _includedAddonIds.contains(id);

                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _includedAddonIds.add(id);
                          } else {
                            _includedAddonIds.remove(id);
                          }
                        });
                      },
                    );
                  }),
                ],
              ],
            ),
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

class _ChipLabel extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const _ChipLabel({
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceInfoTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _ServiceInfoTile({
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
