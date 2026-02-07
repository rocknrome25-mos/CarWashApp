// C:\dev\carwash\client_module\lib\features\bookings\waitlist_page.dart
import 'dart:async';

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

  StreamSubscription? _subRefresh;
  StreamSubscription? _subEvents;
  Timer? _debounce;

  // ✅ prevent double taps
  bool _canceling = false;

  @override
  void initState() {
    super.initState();
    _subscribeRefresh();
    load(force: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subRefresh?.cancel();
    _subEvents?.cancel();
    super.dispose();
  }

  void _subscribeRefresh() {
    _subRefresh?.cancel();
    _subEvents?.cancel();

    // 1) repo.refresh$ if exists
    try {
      final dyn = widget.repo as dynamic;
      final candidate = dyn.refresh$;
      if (candidate is Stream) {
        _subRefresh = candidate.listen((_) => _onAnyRefreshEvent());
      }
    } catch (_) {
      _subRefresh = null;
    }

    // 2) always listen bookingEvents as fallback
    _subEvents = widget.repo.bookingEvents.listen((_) => _onAnyRefreshEvent());
  }

  void _onAnyRefreshEvent() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      load(force: true);
    });
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
    final up = r.toUpperCase();
    if (up.contains('ALL_BAYS_CLOSED')) {
      return 'Посты закрыты. Ожидаем открытие.';
    }
    if (up.contains('BAY_CLOSED')) return 'Пост закрыт. Ожидаем открытие.';
    if (up.contains('CLIENT_CANCELED')) return 'Вы отменили ожидание.';
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

  Widget _sectionCard({required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _cancelWaitlist(Map<String, dynamic> w) async {
    if (_canceling) return;

    final wid = _s(w, 'id');
    if (wid.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Убрать из ожидания?'),
        content: const Text(
          'Заявка будет отменена и исчезнет из очереди ожидания.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    setState(() => _canceling = true);

    try {
      // ✅ We prefer a strongly-typed method if you added it:
      // ApiRepository.cancelWaitlistRequest(waitlistId)
      final dyn = widget.repo as dynamic;

      Future<void> call() async {
        // Most likely name (the one I gave you)
        if (dyn.cancelWaitlistRequest is Function) {
          await dyn.cancelWaitlistRequest(wid);
          return;
        }
        // Alternative name if you chose differently
        if (dyn.cancelWaitlist is Function) {
          await dyn.cancelWaitlist(wid);
          return;
        }
        throw Exception('CANCEL_WAITLIST_NOT_IMPLEMENTED');
      }

      await call();

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Заявка в ожидании отменена'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await load(force: true);

      // ✅ optional: go back automatically if queue is empty
      if (!mounted) return;
      if (rows.isEmpty) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().contains('CANCEL_WAITLIST_NOT_IMPLEMENTED')
          ? 'Отмена ожидания пока не подключена на сервере.'
          : 'Ошибка: $e';

      messenger.showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _canceling = false);
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

                return _sectionCard(
                  title: serviceName,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 12),
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
                                        alpha: 0.88,
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
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 12),

                      // ✅ Cancel waitlist (double-click safe)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_canceling || loading)
                              ? null
                              : () => _cancelWaitlist(w),
                          icon: _canceling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: Text(
                            _canceling ? 'Отменяю...' : 'Отменить ожидание',
                          ),
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
