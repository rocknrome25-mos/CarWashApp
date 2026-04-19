import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

class OwnerSettingsTab extends StatefulWidget {
  const OwnerSettingsTab({super.key});

  @override
  State<OwnerSettingsTab> createState() => _OwnerSettingsTabState();
}

class _OwnerSettingsTabState extends State<OwnerSettingsTab> {
  late Future<_OwnerSettingsData> _future;

  bool _isBusy = false;
  bool _initialized = false;

  String _locationId = '';
  String _locationName = 'Локация';
  String _locationAddress = '';
  String _locationColorHex = '#2D9CDB';

  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _telegramController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _navigatorLinkController = TextEditingController();
  final _mapsLinkController = TextEditingController();

  final _washStartTemplateController = TextEditingController();
  final _washFinishTemplateController = TextEditingController();
  final _notifyPhoneController = TextEditingController();
  final _notifyTelegramController = TextEditingController();

  bool _promotionsEnabled = false;
  bool _discountsEnabled = false;
  bool _holidayGreetingsEnabled = false;
  bool _notifyPush = true;

  final Set<String> _selectedSuspiciousTypes = {};
  List<_AuditOption> _auditOptions = const [];

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _telegramController.dispose();
    _whatsappController.dispose();
    _navigatorLinkController.dispose();
    _mapsLinkController.dispose();
    _washStartTemplateController.dispose();
    _washFinishTemplateController.dispose();
    _notifyPhoneController.dispose();
    _notifyTelegramController.dispose();
    super.dispose();
  }

  Future<_OwnerSettingsData> _loadData() async {
    final uri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/settings');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Owner settings response is not an object');
    }

    return _OwnerSettingsData.fromJson(decoded);
  }

  void _syncFromData(_OwnerSettingsData data) {
    if (_initialized) return;

    _locationId = data.locationId;
    _locationName = data.locationName;
    _locationAddress = data.locationAddress;
    _locationColorHex = data.locationColorHex;

    _titleController.text = data.contactsTitle;
    _addressController.text = data.contactsAddress;
    _phoneController.text = data.phone;
    _telegramController.text = data.telegram;
    _whatsappController.text = data.whatsapp;
    _navigatorLinkController.text = data.navigatorLink;
    _mapsLinkController.text = data.mapsLink;

    _washStartTemplateController.text = data.washStartTemplate;
    _washFinishTemplateController.text = data.washFinishTemplate;
    _notifyPhoneController.text = data.notifyPhone;
    _notifyTelegramController.text = data.notifyTelegram;

    _promotionsEnabled = data.promotionsEnabled;
    _discountsEnabled = data.discountsEnabled;
    _holidayGreetingsEnabled = data.holidayGreetingsEnabled;
    _notifyPush = data.notifyPush;

    _selectedSuspiciousTypes
      ..clear()
      ..addAll(data.selectedSuspiciousTypes);

    _auditOptions = data.auditOptions;

    _initialized = true;
  }

  Future<void> _reload() async {
    setState(() {
      _initialized = false;
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _saveContacts() async {
    if (_isBusy || _locationId.isEmpty) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.defaultBaseUrl}/config/contacts?locationId=$_locationId',
      );

      final body = {
        'title': _titleController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'telegram': _telegramController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'navigatorLink': _navigatorLinkController.text.trim(),
        'mapsLink': _mapsLinkController.text.trim(),
      };

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Контакты сохранены')));

      await _reload();
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

  Future<void> _saveSettings() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final uri = Uri.parse('${AppConfig.defaultBaseUrl}/owner/settings');

      final body = {
        'communication': {
          'washStartTemplate': _washStartTemplateController.text.trim(),
          'washFinishTemplate': _washFinishTemplateController.text.trim(),
          'campaigns': {
            'promotionsEnabled': _promotionsEnabled,
            'discountsEnabled': _discountsEnabled,
            'holidayGreetingsEnabled': _holidayGreetingsEnabled,
          },
        },
        'monitoring': {
          'suspiciousAuditTypes': _selectedSuspiciousTypes.toList(),
          'notifyPhone': _notifyPhoneController.text.trim(),
          'notifyTelegram': _notifyTelegramController.text.trim(),
          'notifyPush': _notifyPush,
        },
      };

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Настройки сохранены')));

      await _reload();
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

  Future<void> _openPasswordDialog() async {
    if (_isBusy) return;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangeOwnerPasswordDialog(),
    );

    if (!mounted) return;

    if (changed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль owner-кабинета изменён')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          FutureBuilder<_OwnerSettingsData>(
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
              _syncFromData(data);

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text('Настройки', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Коммуникации и контроль для локации $_locationName',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            title: 'Локация',
                            value: _locationName,
                            subtitle: _locationAddress.isEmpty
                                ? 'Адрес не указан'
                                : _locationAddress,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoTile(
                            title: 'Цвет интерфейса',
                            value: _locationColorHex,
                            subtitle: 'Пока только просмотр',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _SectionCard(
                      title: 'Контакты для клиента',
                      subtitle:
                          'Используется существующая логика /config и /config/contacts',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Телефон',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _telegramController,
                            decoration: const InputDecoration(
                              labelText: 'Telegram / Telegram-канал',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _whatsappController,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _navigatorLinkController,
                            decoration: const InputDecoration(
                              labelText: 'Ссылка навигатора',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreviewBox(
                            title: 'Как это увидит клиент',
                            child: _ClientContactsPreview(
                              title: _titleController.text.trim().isEmpty
                                  ? _locationName
                                  : _titleController.text.trim(),
                              address: _addressController.text.trim(),
                              phone: _phoneController.text.trim(),
                              telegram: _telegramController.text.trim(),
                              whatsapp: _whatsappController.text.trim(),
                              navigatorLink: _navigatorLinkController.text
                                  .trim(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isBusy ? null : _saveContacts,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Сохранить контакты'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Шаблоны сообщений клиентам',
                      subtitle:
                          'Тексты начала и окончания мойки, которые владелец может менять',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _washStartTemplateController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Начало мойки',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _washFinishTemplateController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Окончание мойки',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreviewBox(
                            title: 'Предпросмотр сообщений',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MessagePreviewBubble(
                                  title: 'Начало мойки',
                                  text: _washStartTemplateController.text
                                      .trim(),
                                ),
                                const SizedBox(height: 12),
                                _MessagePreviewBubble(
                                  title: 'Окончание мойки',
                                  text: _washFinishTemplateController.text
                                      .trim(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Рассылки',
                      subtitle:
                          'Только управляемые owner настройки без критических параметров внедрения',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Акции'),
                            value: _promotionsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _promotionsEnabled = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Скидки'),
                            value: _discountsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _discountsEnabled = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Поздравления / праздники'),
                            value: _holidayGreetingsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _holidayGreetingsEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Подозрительные события',
                      subtitle:
                          'Владелец выбирает, за какими событиями следить',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._auditOptions.map(
                            (item) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.label),
                              value: _selectedSuspiciousTypes.contains(
                                item.key,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedSuspiciousTypes.add(item.key);
                                  } else {
                                    _selectedSuspiciousTypes.remove(item.key);
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notifyPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Куда слать уведомления: телефон',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notifyTelegramController,
                            decoration: const InputDecoration(
                              labelText: 'Куда слать уведомления: Telegram',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Push-уведомления'),
                            subtitle: const Text(
                              'Отправлять уведомления в owner-приложение',
                            ),
                            value: _notifyPush,
                            onChanged: (value) {
                              setState(() {
                                _notifyPush = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isBusy ? null : _saveSettings,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Сохранить настройки'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Безопасность',
                      subtitle: 'Смена пароля owner-кабинета',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _isBusy ? null : _openPasswordDialog,
                          icon: const Icon(Icons.lock_reset_outlined),
                          label: const Text('Сменить пароль'),
                        ),
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

class _OwnerSettingsData {
  final String locationId;
  final String locationName;
  final String locationAddress;
  final String locationColorHex;

  final String contactsTitle;
  final String contactsAddress;
  final String phone;
  final String telegram;
  final String whatsapp;
  final String navigatorLink;
  final String mapsLink;

  final String washStartTemplate;
  final String washFinishTemplate;

  final bool promotionsEnabled;
  final bool discountsEnabled;
  final bool holidayGreetingsEnabled;

  final List<String> selectedSuspiciousTypes;
  final String notifyPhone;
  final String notifyTelegram;
  final bool notifyPush;

  final List<_AuditOption> auditOptions;

  const _OwnerSettingsData({
    required this.locationId,
    required this.locationName,
    required this.locationAddress,
    required this.locationColorHex,
    required this.contactsTitle,
    required this.contactsAddress,
    required this.phone,
    required this.telegram,
    required this.whatsapp,
    required this.navigatorLink,
    required this.mapsLink,
    required this.washStartTemplate,
    required this.washFinishTemplate,
    required this.promotionsEnabled,
    required this.discountsEnabled,
    required this.holidayGreetingsEnabled,
    required this.selectedSuspiciousTypes,
    required this.notifyPhone,
    required this.notifyTelegram,
    required this.notifyPush,
    required this.auditOptions,
  });

  factory _OwnerSettingsData.fromJson(Map<String, dynamic> json) {
    final location = Map<String, dynamic>.from(
      (json['location'] as Map?) ?? const {},
    );
    final contacts = Map<String, dynamic>.from(
      (json['contacts'] as Map?) ?? const {},
    );
    final settings = Map<String, dynamic>.from(
      (json['settings'] as Map?) ?? const {},
    );
    final communication = Map<String, dynamic>.from(
      (settings['communication'] as Map?) ?? const {},
    );
    final campaigns = Map<String, dynamic>.from(
      (communication['campaigns'] as Map?) ?? const {},
    );
    final monitoring = Map<String, dynamic>.from(
      (settings['monitoring'] as Map?) ?? const {},
    );
    final options = Map<String, dynamic>.from(
      (json['options'] as Map?) ?? const {},
    );

    final rawAuditOptions =
        ((options['suspiciousAuditTypes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final auditOptions = rawAuditOptions
        .map(
          (e) => _AuditOption(
            key: (e['key'] ?? '').toString(),
            label: (e['label'] ?? '').toString(),
          ),
        )
        .where((e) => e.key.isNotEmpty && e.label.isNotEmpty)
        .toList();

    final selected = ((monitoring['suspiciousAuditTypes'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return _OwnerSettingsData(
      locationId: (location['id'] ?? '').toString(),
      locationName: (location['name'] ?? 'Локация').toString(),
      locationAddress: (location['address'] ?? '').toString(),
      locationColorHex: (location['colorHex'] ?? '#2D9CDB').toString(),
      contactsTitle: (contacts['title'] ?? '').toString(),
      contactsAddress: (contacts['address'] ?? '').toString(),
      phone: (contacts['phone'] ?? '').toString(),
      telegram: (contacts['telegram'] ?? '').toString(),
      whatsapp: (contacts['whatsapp'] ?? '').toString(),
      navigatorLink: (contacts['navigatorLink'] ?? '').toString(),
      mapsLink: (contacts['mapsLink'] ?? '').toString(),
      washStartTemplate: (communication['washStartTemplate'] ?? '').toString(),
      washFinishTemplate: (communication['washFinishTemplate'] ?? '')
          .toString(),
      promotionsEnabled: campaigns['promotionsEnabled'] == true,
      discountsEnabled: campaigns['discountsEnabled'] == true,
      holidayGreetingsEnabled: campaigns['holidayGreetingsEnabled'] == true,
      selectedSuspiciousTypes: selected,
      notifyPhone: (monitoring['notifyPhone'] ?? '').toString(),
      notifyTelegram: (monitoring['notifyTelegram'] ?? '').toString(),
      notifyPush: monitoring['notifyPush'] != false,
      auditOptions: auditOptions,
    );
  }
}

class _AuditOption {
  final String key;
  final String label;

  const _AuditOption({required this.key, required this.label});
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final String title;
  final Widget child;

  const _PreviewBox({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ClientContactsPreview extends StatelessWidget {
  final String title;
  final String address;
  final String phone;
  final String telegram;
  final String whatsapp;
  final String navigatorLink;

  const _ClientContactsPreview({
    required this.title,
    required this.address,
    required this.phone,
    required this.telegram,
    required this.whatsapp,
    required this.navigatorLink,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<IconData, String>>[
      MapEntry(Icons.phone_outlined, phone),
      MapEntry(Icons.telegram_outlined, telegram),
      MapEntry(Icons.message_outlined, whatsapp),
      MapEntry(Icons.navigation_outlined, navigatorLink),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.trim().isEmpty ? 'Контакты' : title.trim(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (address.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            address.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('Контакты пока не заполнены')
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(row.key, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.value)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MessagePreviewBubble extends StatelessWidget {
  final String title;
  final String text;

  const _MessagePreviewBubble({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final content = text.trim().isEmpty ? 'Текст не задан' : text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
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
          Text(value, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
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

class _ChangeOwnerPasswordDialog extends StatefulWidget {
  const _ChangeOwnerPasswordDialog();

  @override
  State<_ChangeOwnerPasswordDialog> createState() =>
      _ChangeOwnerPasswordDialogState();
}

class _ChangeOwnerPasswordDialogState
    extends State<_ChangeOwnerPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
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
        '${AppConfig.defaultBaseUrl}/owner/change-password',
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
      title: const Text('Смена пароля'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Повторите пароль',
                ),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Повторите пароль';
                  if (v != _passwordController.text.trim()) {
                    return 'Пароли не совпадают';
                  }
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
