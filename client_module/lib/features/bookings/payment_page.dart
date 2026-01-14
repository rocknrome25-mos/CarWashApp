import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/service.dart';

class PaymentPage extends StatefulWidget {
  final AppRepository repo;
  final Booking booking;
  final Service? service;

  // ✅ депозит (оплата брони)
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
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) => _syncBooking());

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
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
        _close(true, toast: 'Бронь оплачена. Запись подтверждена.');
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
      // молча
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
        const SnackBar(content: Text('Время на оплату истекло. Обновляю статус...')),
      );
      await _syncBooking();
      return;
    }

    setState(() => _paying = true);

    try {
      final current = _booking ?? widget.booking;

      await widget.repo.payBooking(
        bookingId: current.id,
        method: 'CARD_TEST',
      );

      if (!mounted || _closing) return;

      _close(true, toast: 'Оплата брони прошла. Запись подтверждена.');
    } catch (e) {
      if (!mounted || _closing) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка оплаты: $e')),
      );

      await _syncBooking();
    } finally {
      if (mounted && !_closing) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking ?? widget.booking;

    final service = widget.service;
    final title = service?.name ?? 'Услуга';

    final total = service?.priceRub;
    final remaining =
        (total == null) ? null : ((total - widget.depositRub) > 0 ? (total - widget.depositRub) : 0);

    final isPending = b.status == BookingStatus.pendingPayment;
    final hasDue = _dueAt != null;
    final canPay = isPending && (!hasDue || _left != Duration.zero) && !_paying && !_closing;

    return Scaffold(
      appBar: AppBar(title: const Text('Оплата брони')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            Text('Оплата брони: ${widget.depositRub} ₽', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),

            if (remaining != null)
              Text(
                'Остаток к оплате на месте: $remaining ₽',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
              ),

            const SizedBox(height: 14),

            if (_dueAt != null) ...[
              Text(
                'Осталось на оплату: ${_fmt(_left)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _left == Duration.zero ? Colors.red : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _left == Duration.zero
                    ? 'Дедлайн прошёл — запись отменится автоматически.'
                    : 'Если не оплатить вовремя — запись отменится автоматически.',
              ),
            ] else ...[
              const Text('Дедлайн оплаты не задан.'),
            ],

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPay ? _pay : null,
                icon: const Icon(Icons.credit_card),
                label: Text(_paying ? 'Оплачиваю...' : 'Оплатить бронь (тест)'),
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
