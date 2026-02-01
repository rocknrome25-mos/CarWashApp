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

      final fresh = list
          .where((b) => b.id == (_booking ?? widget.booking).id)
          .firstOrNull;

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
      // silently
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

  // ---- addons safe ----
  List<Map<String, dynamic>> _addonsSafe(Booking b) {
    try {
      final dyn = b as dynamic;
      final addons = dyn.addons;
      if (addons is List) {
        final out = <Map<String, dynamic>>[];
        for (final x in addons) {
          if (x is Map) {
            out.add(x.cast<String, dynamic>());
          } else {
            try {
              final dx = x as dynamic;
              out.add({
                'qty': dx.qty,
                'priceRubSnapshot': dx.priceRubSnapshot,
                'durationMinSnapshot': dx.durationMinSnapshot,
                'service': dx.service,
                'serviceId': dx.serviceId,
              });
            } catch (_) {}
          }
        }
        return out;
      }
    } catch (_) {}
    return const [];
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

  int _addonsTotalPriceRub(List<Map<String, dynamic>> addons) {
    int sum = 0;
    for (final a in addons) {
      final qty = (a['qty'] is num) ? (a['qty'] as num).toInt() : 1;
      final price = (a['priceRubSnapshot'] is num)
          ? (a['priceRubSnapshot'] as num).toInt()
          : 0;
      sum += max(qty, 1) * max(price, 0);
    }
    return sum;
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

  Widget _card(BuildContext context, {required Widget child}) {
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
    final addonsPrice = _addonsTotalPriceRub(addons);

    final baseTotal = service?.priceRub ?? 0;
    final total = baseTotal + addonsPrice;

    final remaining = max(total - widget.depositRub, 0);

    final isPending = b.status == BookingStatus.pendingPayment;
    final hasDue = _dueAt != null;

    final canPay =
        isPending &&
        (!hasDue || _left != Duration.zero) &&
        !_paying &&
        !_closing;

    return Scaffold(
      appBar: AppBar(title: Text('Бронирование ${widget.depositRub} ₽')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Бронирование (депозит)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Text(
                        '${widget.depositRub} ₽',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Остаток на месте',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Text(
                        '$remaining ₽',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),

                  if (addons.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.55)),
                    const SizedBox(height: 10),
                    Text(
                      'Доп. услуги',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final a in addons) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _addonName(a),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface.withValues(alpha: 0.9),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '+${(a['priceRubSnapshot'] is num) ? (a['priceRubSnapshot'] as num).toInt() : 0} ₽',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Итого по доп. услугам: +$addonsPrice ₽',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  if (_dueAt != null) ...[
                    Text(
                      'Осталось на оплату: ${_fmt(_left)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _left == Duration.zero ? cs.error : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _left == Duration.zero
                          ? 'Дедлайн прошёл — запись отменится автоматически.'
                          : 'Если не оплатить вовремя — запись отменится автоматически.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Дедлайн оплаты не задан.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

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

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
