import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';

class BookingDetailsPage extends StatefulWidget {
  final AppRepository repo;
  final String bookingId;

  const BookingDetailsPage({
    super.key,
    required this.repo,
    required this.bookingId,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  late Future<_Details> _future;
  bool _canceling = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Details> _load({bool forceRefresh = false}) async {
    final bookings = await widget.repo.getBookings(
      includeCanceled: true,
      forceRefresh: forceRefresh,
    );
    final booking = bookings.where((b) => b.id == widget.bookingId).firstOrNull;

    final cars = await widget.repo.getCars(forceRefresh: forceRefresh);
    final services = await widget.repo.getServices(forceRefresh: forceRefresh);

    final car = booking == null
        ? null
        : cars.where((c) => c.id == booking.carId).firstOrNull;

    final service = booking == null
        ? null
        : services.where((s) => s.id == booking.serviceId).firstOrNull;

    return _Details(booking: booking, car: car, service: service);
  }

  String _dtText(DateTime dt) {
    final x = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(x.day)}.${two(x.month)}.${x.year} ${two(x.hour)}:${two(x.minute)}';
  }

  Widget _statusChip(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingPayment:
        return const Chip(label: Text('ОЖИДАЕТ ОПЛАТЫ'), side: BorderSide.none);
      case BookingStatus.canceled:
        return const Chip(label: Text('ОТМЕНЕНА'), side: BorderSide.none);
      case BookingStatus.completed:
        return const Chip(label: Text('ЗАВЕРШЕНА'), side: BorderSide.none);
      case BookingStatus.active:
        return const Chip(label: Text('АКТИВНА'), side: BorderSide.none);
    }
  }

  Widget _paidChip() {
    return const Chip(label: Text('ОПЛАЧЕНО'), side: BorderSide.none);
  }

  String? _paymentHint(Booking b) {
    if (b.status != BookingStatus.pendingPayment) return null;
    if (b.paymentDueAt == null) return 'Ожидается оплата';
    return 'Оплатить до: ${_dtText(b.paymentDueAt!)}';
  }

  String _paymentStatusLine(Booking b) {
    if (b.paidAt != null) {
      return 'Оплата: оплачено • ${_dtText(b.paidAt!)}';
    }
    if (b.status == BookingStatus.pendingPayment) {
      return 'Оплата: ожидается';
    }
    if (b.status == BookingStatus.active) {
      return 'Оплата: не подтверждена';
    }
    return 'Оплата: —';
  }

  Future<void> _confirmAndCancel(String bookingId) async {
    if (_canceling) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: const Text('Запись будет помечена как отменённая.'),
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

    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.repo.cancelBooking(bookingId);
      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('Запись отменена')));

      setState(() {
        _canceling = false;
        _future = _load(forceRefresh: true);
      });

      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _canceling = false);
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Детали записи')),
      body: FutureBuilder<_Details>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _future = _load(forceRefresh: true)),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data;
          final booking = data?.booking;

          if (booking == null) {
            return const Center(child: Text('Запись не найдена'));
          }

          final car = data?.car;
          final service = data?.service;

          final isCanceled = booking.status == BookingStatus.canceled;
          final isCompleted = booking.status == BookingStatus.completed;

          final canCancel = !(isCanceled || isCompleted);
          final paymentHint = _paymentHint(booking);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service?.name ?? 'Услуга удалена',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_dtText(booking.dateTime)),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(booking.status),
                    if (booking.paidAt != null) _paidChip(),
                  ],
                ),

                const SizedBox(height: 8),
                Text(_paymentStatusLine(booking)),

                if (paymentHint != null) ...[
                  const SizedBox(height: 8),
                  Text(paymentHint),
                ],

                const SizedBox(height: 16),
                const Text(
                  'Авто',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(car == null ? 'Авто удалено' : '${car.make} ${car.model}'),
                if (car != null) Text(car.subtitle),

                const SizedBox(height: 16),
                const Text(
                  'Стоимость',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(service == null ? '—' : '${service.priceRub} ₽'),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (canCancel && !_canceling)
                        ? () => _confirmAndCancel(booking.id)
                        : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(_canceling ? 'Отменяю...' : 'Отменить запись'),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Назад'),
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

class _Details {
  final Booking? booking;
  final Car? car;
  final Service? service;
  _Details({required this.booking, required this.car, required this.service});
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
