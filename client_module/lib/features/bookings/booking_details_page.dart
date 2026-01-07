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

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  /// ✅ Логика статуса для деталей:
  /// - paidAt != null -> ОПЛАЧЕНО
  /// - pendingPayment -> ОЖИДАЕТ ОПЛАТЫ
  /// - completed -> ЗАВЕРШЕНА (серый)
  /// - canceled -> ОТМЕНЕНА (красный)
  /// - active (без paidAt) -> ничего не показываем
  Widget _detailsBadge(Booking b) {
    if (b.paidAt != null) {
      return _badge(text: 'ОПЛАЧЕНО', color: Colors.green);
    }
    if (b.status == BookingStatus.pendingPayment) {
      return _badge(text: 'ОЖИДАЕТ ОПЛАТЫ', color: Colors.orange);
    }
    if (b.status == BookingStatus.completed) {
      return _badge(text: 'ЗАВЕРШЕНА', color: Colors.grey);
    }
    if (b.status == BookingStatus.canceled) {
      return _badge(text: 'ОТМЕНЕНА', color: Colors.red);
    }
    return const SizedBox.shrink();
  }

  ImageProvider _serviceAssetProvider(Service s) {
    final n = s.name.toLowerCase();

    if (n.contains('воск')) {
      return const AssetImage('assets/images/services/vosk_1080.jpg');
    }
    if (n.contains('комплекс')) {
      return const AssetImage('assets/images/services/kompleks_1080.jpg');
    }
    if (n.contains('кузов')) {
      return const AssetImage('assets/images/services/kuzov_1080.jpg');
    }

    // безопасный fallback (любой существующий файл)
    return const AssetImage('assets/images/services/kuzov_1080.jpg');
  }

  Widget _serviceThumb(Service? service) {
    // service отсутствует
    if (service == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.local_car_wash),
      );
    }

    // приоритет: network
    final url = service.imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 56,
            height: 56,
            color: Colors.black.withValues(alpha: 0.04),
            child: const Icon(Icons.local_car_wash),
          ),
        ),
      );
    }

    // fallback: assets
    final provider = _serviceAssetProvider(service);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image(
        image: provider,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: Colors.black.withValues(alpha: 0.04),
          child: const Icon(Icons.local_car_wash),
        ),
      ),
    );
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

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _canceling = false);
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: child,
    );
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

          final badge = _detailsBadge(booking);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _serviceThumb(service),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  service?.name ?? 'Услуга удалена',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              badge,
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dtText(booking.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (booking.paidAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Оплата: ${_dtText(booking.paidAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          if (booking.status == BookingStatus.pendingPayment &&
                              booking.paymentDueAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Оплатить до: ${_dtText(booking.paymentDueAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Авто',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      car == null
                          ? 'Авто удалено'
                          : '${car.make} ${car.model} (${car.plateDisplay})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (car != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        car.subtitle,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Стоимость',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service == null ? '—' : '${service.priceRub} ₽',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Назад'),
                ),
              ),
            ],
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
