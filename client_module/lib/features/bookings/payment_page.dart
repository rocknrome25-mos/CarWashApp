import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/service.dart';

class PaymentPage extends StatefulWidget {
  final AppRepository repo;
  final Booking booking;
  final Service? service;

  const PaymentPage({
    super.key,
    required this.repo,
    required this.booking,
    required this.service,
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

  // ✅ prevents double pop / navigation races
  bool _closing = false;

  DateTime? get _dueAt => _booking?.paymentDueAt;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;

    _recalc();

    // тик для отображения таймера
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _recalc());

    // синхронизация статуса с бэком
    _syncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _syncBooking(),
    );

    // первый sync сразу
    _syncBooking();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  // ✅ One safe exit point
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

    // microtask to avoid "pop during build / pop during async tick" issues
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

      // ✅ if status changed — close page once
      if (fresh.status == BookingStatus.active) {
        _close(true, toast: 'Запись подтверждена.');
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
      // молча: не спамим каждые 3 сек
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

    // если дедлайн уже 0 — ждём авто-отмену/синк
    if (_left == Duration.zero) {
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

      await widget.repo.payBooking(
        bookingId: current.id, // ✅ pay current booking id
        method: 'CARD_TEST',
      );

      if (!mounted || _closing) return;

      // Можно либо сразу закрыть, либо дать синку подтвердить.
      // Я закрываю сразу, чтобы UI не зависел от таймера.
      _close(true, toast: 'Оплата прошла. Запись подтверждена.');
    } catch (e) {
      if (!mounted || _closing) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка оплаты: $e')));

      // подтянем статус (вдруг уже отменили/подтвердили)
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
    final price = service == null ? '—' : '${service.priceRub} ₽';

    final isPending = b.status == BookingStatus.pendingPayment;
    final canPay = isPending && _left != Duration.zero && !_paying && !_closing;

    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Стоимость: $price'),
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
              const Text(
                'Нет дедлайна оплаты (backend не вернул paymentDueAt).',
              ),
            ],

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canPay ? _pay : null,
                icon: const Icon(Icons.credit_card),
                label: Text(_paying ? 'Оплачиваю...' : 'Оплатить (тест)'),
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
