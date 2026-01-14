import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsPage extends StatelessWidget {
  final String title;
  final String address;
  final String phone;
  final String telegram; // например: @carwash_moscow или carwash_moscow
  final String navigatorLink; // ссылка на карты (например Google Maps)

  const ContactsPage({
    super.key,
    required this.title,
    required this.address,
    required this.phone,
    required this.telegram,
    required this.navigatorLink,
  });

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось открыть: $uri')));
    }
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label скопирован')));
  }

  String _normalizeTelegram(String t) {
    final x = t.trim();
    if (x.isEmpty) return '';
    return x.startsWith('@') ? x.substring(1) : x;
  }

  String _digitsPhone(String p) {
    // оставляем + и цифры
    final sb = StringBuffer();
    for (final ch in p.trim().split('')) {
      final code = ch.codeUnitAt(0);
      final isDigit = code >= 48 && code <= 57;
      if (ch == '+' || isDigit) sb.write(ch);
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tgUser = _normalizeTelegram(telegram);
    final phoneDigits = _digitsPhone(phone);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _CardSection(
            title: 'Связь',
            children: [
              _ActionTile(
                icon: Icons.phone,
                title: phone,
                subtitle: 'Нажми, чтобы позвонить',
                onTap: () => _openUrl(context, Uri.parse('tel:$phoneDigits')),
                onLongPress: () => _copy(context, 'Телефон', phone),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.telegram,
                title: tgUser.isEmpty ? 'Telegram' : '@$tgUser',
                subtitle: 'Открыть чат в Telegram',
                onTap: () {
                  if (tgUser.isEmpty) return;
                  _openUrl(context, Uri.parse('tg://resolve?domain=$tgUser'));
                },
                trailing: IconButton(
                  tooltip: 'Открыть через браузер',
                  onPressed: tgUser.isEmpty
                      ? null
                      : () => _openUrl(
                          context,
                          Uri.parse('https://t.me/$tgUser'),
                        ),
                  icon: const Icon(Icons.open_in_new),
                ),
                onLongPress: () => _copy(context, 'Telegram', '@$tgUser'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CardSection(
            title: 'Адрес',
            children: [
              _ActionTile(
                icon: Icons.location_on,
                title: address,
                subtitle: 'Нажми, чтобы открыть навигатор',
                onTap: () => _openUrl(context, Uri.parse(navigatorLink)),
                onLongPress: () => _copy(context, 'Адрес', address),
              ),
              const SizedBox(height: 10),
              _SmallButtonsRow(
                onCopy: () => _copy(context, 'Адрес', address),
                onMaps: () => _openUrl(context, Uri.parse(navigatorLink)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Подсказка: долгое нажатие копирует телефон/адрес.',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CardSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.04),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).cardColor,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.04),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.60),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class _SmallButtonsRow extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback onMaps;

  const _SmallButtonsRow({required this.onCopy, required this.onMaps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy),
            label: const Text('Копировать'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onMaps,
            icon: const Icon(Icons.navigation),
            label: const Text('Навигатор'),
          ),
        ),
      ],
    );
  }
}
