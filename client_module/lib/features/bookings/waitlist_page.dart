import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/app_repository.dart';

class WaitlistPage extends StatefulWidget {
  final AppRepository repo;

  const WaitlistPage({super.key, required this.repo});

  @override
  State<WaitlistPage> createState() => _WaitlistPageState();
}

class _WaitlistPageState extends State<WaitlistPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    load(force: true);
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final cid = widget.repo.currentClient?.id.trim() ?? '';
      if (cid.isEmpty) {
        throw Exception('Нет активного клиента. Перезайди.');
      }
      final list = await widget.repo.getWaitlist(
        clientId: cid,
        includeAll: false,
      );
      if (!mounted) return;
      setState(() => rows = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _s(Map<String, dynamic> m, String key) =>
      (m[key] ?? '').toString().trim();

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _reasonRu(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return 'Ожидаем свободный пост';
    if (r == 'ALL_BAYS_CLOSED') return 'Посты закрыты. Ожидаем открытие.';
    return r;
  }

  Future<void> _openUrl(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось открыть: $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ожидание'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ошибка: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.9)),
                ),
              ),
            )
          : rows.isEmpty
          ? Center(
              child: Text(
                'Очередь пуста',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final w = rows[i];

                final serviceName = (w['service']?['name'] ?? 'Услуга')
                    .toString();
                final carPlate = (w['car']?['plateDisplay'] ?? '')
                    .toString()
                    .trim();
                final carMake = (w['car']?['makeDisplay'] ?? '')
                    .toString()
                    .trim();

                final dtIso = _s(w, 'desiredDateTime').isNotEmpty
                    ? _s(w, 'desiredDateTime')
                    : _s(w, 'dateTime');

                final reason = _reasonRu(_s(w, 'reason'));

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fmtTime(dtIso),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (carPlate.isNotEmpty || carMake.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${carMake.isEmpty ? '' : '$carMake • '}${carPlate.isEmpty ? '' : carPlate}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_bottom, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reason,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSurface.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Мы свяжемся, когда появится свободное окно.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Контакты (быстро, без config — если у тебя уже есть /config, можно потом подтянуть)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openUrl(Uri.parse('tel:+79000000000')),
                            icon: const Icon(Icons.phone),
                            label: const Text('Позвонить'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openUrl(
                              Uri.parse('https://t.me/carwash_demo'),
                            ),
                            icon: const Icon(Icons.telegram),
                            label: const Text('Telegram'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openUrl(
                              Uri.parse('https://wa.me/79000000000'),
                            ),
                            icon: const Icon(Icons.chat_bubble),
                            label: const Text('WhatsApp'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
