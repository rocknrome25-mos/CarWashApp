import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/data/app_repository.dart';

class ContactsPage extends StatefulWidget {
  final AppRepository repo;

  const ContactsPage({super.key, required this.repo});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  static const String _fallbackPhone = '+79661580404';
  static const String _fallbackTelegram = '@avtotark10';
  static const String _fallbackWhatsApp = '+79661580404';
  static const String _fallbackNavigatorLink =
      'https://yandex.com/maps/213/moscow/house/bulvar_andreya_tarkovskogo_10/Z04YdQNgSUcOQFtvfXpzdHplbQ==/?ll=37.341503%2C55.624996&z=17.65';

  static const String _phoneAsset = 'assets/images/social/phone.png';
  static const String _telegramAsset = 'assets/images/social/telegram.png';
  static const String _whatsAppAsset = 'assets/images/social/whatsapp.png';

  bool loading = true;
  String? error;
  Map<String, dynamic> cfg = const {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final loc = widget.repo.currentLocation;
      final locId = (loc?.id ?? '').trim();

      if (locId.isEmpty) {
        throw Exception('Локация не выбрана. Зайди в “Услуги” и выбери мойку.');
      }

      final m = await widget.repo.getConfig(
        locationId: locId,
        forceRefresh: force,
      );

      if (!mounted) return;
      setState(() => cfg = m);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _openUrl(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось открыть: $uri')));
    }
  }

  Future<void> _openPreferAppThenWeb(Uri appUri, Uri webUri) async {
    final ok = await launchUrl(appUri, mode: LaunchMode.externalApplication);

    if (ok) return;

    await _openUrl(webUri);
  }

  Future<void> _copy(String label, String value) async {
    final v = value.trim();
    if (v.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: v));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label скопирован'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _str(String key, {String fallback = ''}) {
    final v = cfg[key];
    if (v == null) return fallback;

    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _normalizeTelegram(String t) {
    final x = t.trim();
    if (x.isEmpty) return '';

    return x.startsWith('@') ? x.substring(1) : x;
  }

  String _digitsPhone(String p) {
    final sb = StringBuffer();

    for (final ch in p.trim().split('')) {
      final code = ch.codeUnitAt(0);
      final isDigit = code >= 48 && code <= 57;

      if (ch == '+' || isDigit) {
        sb.write(ch);
      }
    }

    return sb.toString();
  }

  String _waPhone(String phoneDigits) {
    final x = phoneDigits.trim();
    if (x.isEmpty) return '';

    return x.startsWith('+') ? x.substring(1) : x;
  }

  Widget _assetIcon(String assetPath, {IconData fallbackIcon = Icons.chat}) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        assetPath,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Icon(fallbackIcon, color: cs.onSurface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final loc = widget.repo.currentLocation;
    final title = _str('title', fallback: loc?.name ?? 'Контакты');

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ошибка: $error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => load(force: true),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final address = _str('address', fallback: loc?.address ?? '');
    final phone = _str('phone', fallback: _fallbackPhone);
    final whatsapp = _str('whatsapp', fallback: _fallbackWhatsApp);
    final telegramRaw = _str('telegram', fallback: _fallbackTelegram);
    final navigatorLink = _str(
      'navigatorLink',
      fallback: _str('mapsLink', fallback: _fallbackNavigatorLink),
    );

    final tgUser = _normalizeTelegram(telegramRaw);
    final phoneDigits = _digitsPhone(phone);
    final waDigits = _waPhone(_digitsPhone(whatsapp));

    final hasPhone = phoneDigits.isNotEmpty;
    final hasTg = tgUser.isNotEmpty;
    final hasWa = waDigits.isNotEmpty;
    final hasAddr = address.trim().isNotEmpty;
    final hasNav = navigatorLink.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _CardSection(
            title: 'Связь',
            subtitle: 'Телефон и мессенджеры для быстрого контакта',
            children: [
              _ActionTile(
                leading: _assetIcon(_phoneAsset, fallbackIcon: Icons.phone),
                title: hasPhone ? phone : 'Телефон не указан',
                subtitle: hasPhone ? 'Нажми, чтобы позвонить' : null,
                onTap: hasPhone
                    ? () => _openUrl(Uri.parse('tel:$phoneDigits'))
                    : null,
                onLongPress: hasPhone ? () => _copy('Телефон', phone) : null,
                trailing: hasPhone
                    ? IconButton(
                        tooltip: 'Копировать',
                        onPressed: () => _copy('Телефон', phone),
                        icon: const Icon(Icons.copy_rounded),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                leading: _assetIcon(_telegramAsset),
                title: hasTg ? '@$tgUser' : 'Telegram не указан',
                subtitle: hasTg ? 'Открыть чат в Telegram' : null,
                onTap: hasTg
                    ? () => _openPreferAppThenWeb(
                        Uri.parse('tg://resolve?domain=$tgUser'),
                        Uri.parse('https://t.me/$tgUser'),
                      )
                    : null,
                onLongPress: hasTg ? () => _copy('Telegram', '@$tgUser') : null,
                trailing: hasTg
                    ? IconButton(
                        tooltip: 'Открыть в браузере',
                        onPressed: () =>
                            _openUrl(Uri.parse('https://t.me/$tgUser')),
                        icon: const Icon(Icons.open_in_new_rounded),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                leading: _assetIcon(_whatsAppAsset),
                title: hasWa
                    ? (whatsapp.isNotEmpty ? whatsapp : phone)
                    : 'WhatsApp не указан',
                subtitle: hasWa ? 'Открыть чат в WhatsApp' : null,
                onTap: hasWa
                    ? () => _openPreferAppThenWeb(
                        Uri.parse('whatsapp://send?phone=$waDigits'),
                        Uri.parse('https://wa.me/$waDigits'),
                      )
                    : null,
                onLongPress: hasWa
                    ? () => _copy(
                        'WhatsApp',
                        whatsapp.isNotEmpty ? whatsapp : phone,
                      )
                    : null,
                trailing: hasWa
                    ? IconButton(
                        tooltip: 'Открыть в браузере',
                        onPressed: () =>
                            _openUrl(Uri.parse('https://wa.me/$waDigits')),
                        icon: const Icon(Icons.open_in_new_rounded),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: 'Адрес',
            subtitle: 'Построить маршрут или быстро скопировать адрес',
            children: [
              _ActionTile(
                leading: _buildDefaultIcon(context, Icons.location_on_rounded),
                title: hasAddr ? address : 'Адрес не указан',
                subtitle: (hasAddr && hasNav)
                    ? 'Нажми, чтобы открыть навигатор'
                    : null,
                onTap: hasNav ? () => _openUrl(Uri.parse(navigatorLink)) : null,
                onLongPress: hasAddr ? () => _copy('Адрес', address) : null,
              ),
              const SizedBox(height: 12),
              _SmallButtonsRow(
                onCopy: hasAddr ? () => _copy('Адрес', address) : null,
                onMaps: hasNav
                    ? () => _openUrl(Uri.parse(navigatorLink))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Подсказка: долгое нажатие копирует телефон, мессенджер или адрес.',
            style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
              color: cs.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildDefaultIcon(BuildContext context, IconData icon) {
  final cs = Theme.of(context).colorScheme;

  return Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: cs.onSurface),
  );
}

class _CardSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _CardSection({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.96),
              letterSpacing: 0.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                color: cs.onSurface.withValues(alpha: 0.64),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const _ActionTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Theme.of(context).cardColor.withValues(alpha: 0.92),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.50),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: (textTheme.bodyLarge ?? const TextStyle())
                            .copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface.withValues(alpha: 0.96),
                              height: 1.15,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          subtitle!,
                          style: (textTheme.bodySmall ?? const TextStyle())
                              .copyWith(
                                color: cs.onSurface.withValues(alpha: 0.68),
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(
                    color: cs.onSurface.withValues(alpha: 0.88),
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButtonsRow extends StatelessWidget {
  final VoidCallback? onCopy;
  final VoidCallback? onMaps;

  const _SmallButtonsRow({required this.onCopy, required this.onMaps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Копировать'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onMaps,
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('Навигатор'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
