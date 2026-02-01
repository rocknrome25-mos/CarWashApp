import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/service.dart';

class PaymentPage extends StatefulWidget {
  final AppRepository repo;
  final Booking booking;
  final Service? service;

  // депозит (оплата брони)
  final int depositRub;

  const PaymentPage({
    super.key,
    required this.repo,
    required this.booking,
    required this.service,
    required this.depositRub,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Timer? _tickTimer;
  Timer? _syncTimer;

  Booking? _booking;
  Duration _left = Duration.zero;

  bool _paying = false;
  bool _syncing = false;
  bool _closing = false;

  DateTime? get _dueAt => _booking?.paymentDueAt;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;

    _recalc();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _recalc());
    _syncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _syncBooking(),
    );

    _syncBooking();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  // -------- addons helpers --------

  List<Map<String, dynamic>> _addonsSafe(Booking b) => b.addons;

  int _qty(Map<String, dynamic> a) {
    final q = a['qty'];
    if (q is num) return max(q.toInt(), 1);
    return 1;
  }

  int _price(Map<String, dynamic> a) {
    final p = a['priceRubSnapshot'];
    if (p is num) return max(p.toInt(), 0);
    return 0;
  }

  int _dur(Map<String, dynamic> a) {
    final d = a['durationMinSnapshot'];
    if (d is num) return max(d.toInt(), 0);
    return 0;
  }

  String _addonName(Map<String, dynamic> a) {
    final s = a['service'];
    if (s is Map) {
      final name = (s['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    final sid = (a['serviceId'] ?? '').toString().trim();
    return sid.isNotEmpty ? 'Услуга ($sid)' : 'Доп. услуга';
  }

  int _addonsSumRub(List<Map<String, dynamic>> addons) {
    int sum = 0;
    for (final a in addons) {
      sum += _qty(a) * _price(a);
    }
    return sum;
  }

  int _addonsSumMin(List<Map<String, dynamic>> addons) {
    int sum = 0;
    for (final a in addons) {
      sum += _qty(a) * _dur(a);
    }
    return sum;
  }

  // -------- logic --------

  void _close(bool result, {String? toast}) {
    if (_closing) return;
    _closing = true;

    _tickTimer?.cancel();
    _syncTimer?.cancel();

    if (!mounted) return;

    if (toast != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(toast)));
    }

    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context).pop(result);
    });
  }

  void _recalc() {
    final due = _dueAt;
    if (due == null) {
      if (!mounted) return;
      setState(() => _left = Duration.zero);
      return;
    }

    final diff = due.difference(DateTime.now());
    final left = diff.isNegative ? Duration.zero : diff;

    if (!mounted) return;
    if (_left == left) return;
    setState(() => _left = left);
  }

  Future<void> _syncBooking() async {
    if (_syncing || _closing) return;
    _syncing = true;

    try {
      final list = await widget.repo.getBookings(
        includeCanceled: true,
        forceRefresh: true,
      );

      final id = (_booking ?? widget.booking).id;
      Booking? fresh;
      for (final b in list) {
        if (b.id == id) {
          fresh = b;
          break;
        }
      }

      if (!mounted || _closing) return;

      if (fresh == null) {
        _close(false, toast: 'Запись не найдена.');
        return;
      }

      setState(() => _booking = fresh);
      _recalc();

      if (fresh.status == BookingStatus.active) {
        _close(true, toast: 'Бронирование оплачено. Запись подтверждена.');
        return;
      }
      if (fresh.status == BookingStatus.canceled) {
        _close(false, toast: 'Запись отменена.');
        return;
      }
      if (fresh.status == BookingStatus.completed) {
        _close(false, toast: 'Запись уже завершена.');
        return;
      }
    } catch (_) {
      // silent
    } finally {
      _syncing = false;
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${two(m)}:${two(s)}';
  }

  Future<void> _pay() async {
    if (_paying || _closing) return;

    if (_left == Duration.zero && _dueAt != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Время на оплату истекло. Обновляю статус...'),
        ),
      );
      await _syncBooking();
      return;
    }

    setState(() => _paying = true);

    try {
      final current = _booking ?? widget.booking;
      await widget.repo.payBooking(bookingId: current.id, method: 'CARD_TEST');

      if (!mounted || _closing) return;
      _close(true, toast: 'Бронирование оплачено. Запись подтверждена.');
    } catch (e) {
      if (!mounted || _closing) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка оплаты: $e')));
      await _syncBooking();
    } finally {
      if (mounted && !_closing) setState(() => _paying = false);
    }
  }

  Widget _card(Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final b = _booking ?? widget.booking;
    final service = widget.service;
    final title = service?.name ?? 'Услуга';

    final addons = _addonsSafe(b);
    final addonsRub = _addonsSumRub(addons);
    final addonsMin = _addonsSumMin(addons);

    final baseTotal = service?.priceRub ?? 0;
    final totalWithAddons = baseTotal + addonsRub;
    final remaining = max(totalWithAddons - widget.depositRub, 0);

    final isPending = b.status == BookingStatus.pendingPayment;
    final hasDue = _dueAt != null;
    final canPay =
        isPending &&
        (!hasDue || _left != Duration.zero) &&
        !_paying &&
        !_closing;

    return Scaffold(
      appBar: AppBar(title: const Text('Забронировать')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Оплата брони: ${widget.depositRub} ₽',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Стоимость: $totalWithAddons ₽  •  Остаток на месте: $remaining ₽',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (addons.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text(
                      'Дополнительные услуги',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final a in addons) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _qty(a) > 1
                                  ? '${_addonName(a)} × ${_qty(a)}'
                                  : _addonName(a),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface.withValues(alpha: 0.86),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '+${_price(a)} ₽',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: cs.onSurface.withValues(alpha: 0.92),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${_dur(a)} мин',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      'Итого: +$addonsRub ₽ • +$addonsMin мин',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_dueAt != null) ...[
                    Text(
                      'Осталось на оплату: ${_fmt(_left)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _left == Duration.zero
                            ? Colors.red
                            : cs.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _left == Duration.zero
                          ? 'Дедлайн прошёл — запись отменится автоматически.'
                          : 'Если не оплатить вовремя — запись отменится автоматически.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Дедлайн оплаты не задан.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPay ? _pay : null,
                icon: const Icon(Icons.credit_card),
                label: Text(
                  _paying
                      ? 'Бронирую...'
                      : 'Забронировать ${widget.depositRub} ₽',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _closing ? null : () => _close(false),
                child: const Text('Назад'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
