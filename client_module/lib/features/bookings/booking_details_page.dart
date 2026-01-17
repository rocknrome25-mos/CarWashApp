import 'package:flutter/material.dart';
import '../../core/data/app_repository.dart';
import '../../core/models/booking.dart';
import '../../core/models/car.dart';
import '../../core/models/service.dart';
import 'payment_page.dart';

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
  static const int _depositRubFallback = 500;

  // 🎨 брендовый голубой
  static const Color _brandBlue = Color(0xFF2D9CDB);

  late Future<_Details> _future;

  bool _canceling = false;
  bool _paying = false;

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

  String _carTitleForUi(Car c) {
    final make = c.make.trim();
    final model = c.model.trim();
    if (model.isEmpty || model == '—') {
      return '$make (${c.plateDisplay})';
    }
    return '$make $model (${c.plateDisplay})';
  }

  Color _bayColor(int bayId) {
    if (bayId == 1) return _brandBlue;
    if (bayId == 2) {
      return const Color(0xFF6C5CE7); // можно заменить на второй "фирменный"
    }
    return Colors.grey;
  }

  ImageProvider _serviceHero(Service? s) {
    final url = s?.imageUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);

    final name = (s?.name ?? '').toLowerCase();
    if (name.contains('воск')) {
      return const AssetImage('assets/images/services/vosk_1080.jpg');
    }
    if (name.contains('комплекс')) {
      return const AssetImage('assets/images/services/kompleks_1080.jpg');
    }
    if (name.contains('кузов')) {
      return const AssetImage('assets/images/services/kuzov_1080.jpg');
    }
    return const AssetImage('assets/images/services/kuzov_1080.jpg');
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

  Widget _detailsBadge(Booking b) {
    // ✅ более "в одной гамме" (без кричащих цветов)
    switch (b.status) {
      case BookingStatus.active:
        return _badge(text: 'ЗАБРОНИРОВАНО', color: _brandBlue);
      case BookingStatus.pendingPayment:
        return _badge(text: 'ОЖИДАЕТ ОПЛАТЫ', color: Colors.blueGrey);
      case BookingStatus.completed:
        return _badge(text: 'ЗАВЕРШЕНО', color: Colors.black54);
      case BookingStatus.canceled:
        return _badge(text: 'ОТМЕНЕНО', color: Colors.black45);
    }
  }

  bool _canPayDeposit(Booking b) {
    if (b.status != BookingStatus.pendingPayment) return false;

    final due = b.paymentDueAt;
    if (due == null) return true;
    return due.isAfter(DateTime.now());
  }

  Future<void> _payNow({
    required Booking booking,
    required Service? service,
  }) async {
    if (_paying) return;

    final messenger = ScaffoldMessenger.of(context);

    if (!_canPayDeposit(booking)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Оплата недоступна для этой записи.')),
      );
      return;
    }

    setState(() => _paying = true);

    try {
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            repo: widget.repo,
            booking: booking,
            service: service,
            depositRub: booking.depositRub > 0
                ? booking.depositRub
                : _depositRubFallback,
          ),
        ),
      );

      if (!mounted) return;

      if (paid == true) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Бронирование оплачено. Запись подтверждена.'),
          ),
        );
        setState(() {
          _future = _load(forceRefresh: true);
        });
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Оплата не завершена.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
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

  Widget _serviceThumb(Service? service) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image(
        image: _serviceHero(service),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 64,
          height: 64,
          color: Colors.black.withValues(alpha: 0.04),
          child: const Icon(Icons.local_car_wash),
        ),
      ),
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

          final showPayButton = _canPayDeposit(booking);
          final badge = _detailsBadge(booking);

          final total = service?.priceRub;
          final depositRub = booking.depositRub > 0
              ? booking.depositRub
              : _depositRubFallback;
          final remaining = (total == null)
              ? null
              : ((total - depositRub) > 0 ? (total - depositRub) : 0);

          final paidTotal = booking.paidTotalRub;
          final paidLine = (total == null)
              ? null
              : 'Оплачено: $paidTotal ₽ из $total ₽';

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

                          // ✅ пост/линия
                          if (booking.bayId != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _bayColor(booking.bayId!),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Пост: ${booking.bayId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 10),

                          Text(
                            'Оплата брони: $depositRub ₽',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withValues(alpha: 0.80),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (remaining != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Остаток к оплате на месте: $remaining ₽',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],

                          if (paidLine != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              paidLine,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],

                          if (booking.lastPaidAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Последний платёж: ${_dtText(booking.lastPaidAt!)}',
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

              if ((booking.comment ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Комментарий',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booking.comment!.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],

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
                      car == null ? 'Авто удалено' : _carTitleForUi(car),
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

              if (showPayButton) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _paying
                        ? null
                        : () => _payNow(booking: booking, service: service),
                    icon: const Icon(Icons.credit_card),
                    label: Text(
                      _paying ? 'Оплачиваю...' : 'Забронировать $depositRub ₽',
                    ),
                  ),
                ),
              ],

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
