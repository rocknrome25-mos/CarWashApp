import 'dart:async';
import 'dart:math';

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

  static const String _bayAnyIcon = 'assets/images/posts/post_any.png';
  static const String _bayGreenIcon = 'assets/images/posts/post_green.png';
  static const String _bayBlueIcon = 'assets/images/posts/post_blue.png';

  static const Color _greenLine = Color(0xFF2DBD6E);
  static const Color _blueLine = Color(0xFF2D9CDB);

  late Future<_Details> _future;

  bool _canceling = false;
  bool _paying = false;

  // ✅ subscribe to repo.refresh$ (fallback bookingEvents)
  StreamSubscription? _sub;
  Timer? _debounce;

  // Fallback polling: if server doesn't emit WS on start, we still refresh
  Timer? _pollTimer;

  Booking? _lastBooking;
  String? _lastFingerprint; // ✅ to avoid spamming notify

  @override
  void initState() {
    super.initState();
    _future = _load(forceRefresh: false, showNotify: false);
    _subscribeRefresh();
    _startPollingFallback();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _sub?.cancel();
    _sub = null;

    _pollTimer?.cancel();
    _pollTimer = null;

    super.dispose();
  }

  // ✅ Prefer repo.refresh$ if exists (ApiRepository), fallback to bookingEvents
  void _subscribeRefresh() {
    _sub?.cancel();

    Stream<dynamic>? s;
    try {
      final dyn = widget.repo as dynamic;
      final candidate = dyn.refresh$;
      if (candidate is Stream) {
        s = candidate;
      }
    } catch (_) {
      s = null;
    }

    s ??= widget.repo.bookingEvents;

    _sub = s.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _future = _load(forceRefresh: true, showNotify: true);
        });
      });
    });
  }

  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) return;

      final b = _lastBooking;
      if (b == null) return;

      // no polling if finished
      if (b.status == BookingStatus.completed ||
          b.status == BookingStatus.canceled) {
        return;
      }

      final now = DateTime.now();
      final dt = b.dateTime.toLocal();
      final minsFrom = now.difference(dt).inMinutes;

      // window: from -30 minutes to +240 minutes
      final shouldPoll = minsFrom >= -30 && minsFrom <= 240;

      if (shouldPoll) {
        setState(() => _future = _load(forceRefresh: true, showNotify: false));
      }
    });
  }

  String _fingerprint(Booking b) {
    final started = b.startedAt?.toIso8601String() ?? '';
    final finished = b.finishedAt?.toIso8601String() ?? '';
    final due = b.paymentDueAt?.toIso8601String() ?? '';
    return [
      b.id,
      b.status.name,
      b.isWashing ? 'WASHING' : 'NOWASH',
      b.bayId?.toString() ?? '',
      b.dateTime.toIso8601String(),
      started,
      finished,
      due,
      b.paidTotalRub.toString(),
      b.discountRub.toString(),
      (b.discountNote ?? '').trim(),
      (b.comment ?? '').trim(),
    ].join('|');
  }

  Future<_Details> _load({
    bool forceRefresh = false,
    required bool showNotify,
  }) async {
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

    // keep for polling window
    _lastBooking = booking;

    // ✅ notify only when actual booking changed
    if (showNotify && booking != null && mounted) {
      final fp = _fingerprint(booking);
      final changed = fp != _lastFingerprint;
      _lastFingerprint = fp;

      if (changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запись обновлена администратором'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // still keep fingerprint so next time we don't “double notify”
      if (booking != null) {
        _lastFingerprint = _fingerprint(booking);
      }
    }

    return _Details(booking: booking, car: car, service: service);
  }

  // ===== addons safe reader (works even if Booking model doesn't have addons) =====

  List<Map<String, dynamic>> _addonsSafe(Booking b) {
    try {
      final dyn = b as dynamic;
      final addons = dyn.addons;
      if (addons is List) {
        final out = <Map<String, dynamic>>[];
        for (final x in addons) {
          if (x is Map) {
            out.add(Map<String, dynamic>.from(x));
            continue;
          }
          try {
            final dx = x as dynamic;
            out.add(<String, dynamic>{
              'qty': dx.qty,
              'priceRubSnapshot': dx.priceRubSnapshot,
              'durationMinSnapshot': dx.durationMinSnapshot,
              'service': dx.service,
              'serviceId': dx.serviceId,
            });
          } catch (_) {}
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

  int _addonQty(Map<String, dynamic> a) {
    final q = a['qty'];
    if (q is num) return max(q.toInt(), 1);
    return 1;
  }

  int _addonPrice(Map<String, dynamic> a) {
    final p = a['priceRubSnapshot'];
    if (p is num) return max(p.toInt(), 0);
    return 0;
  }

  int _addonDur(Map<String, dynamic> a) {
    final d = a['durationMinSnapshot'];
    if (d is num) return max(d.toInt(), 0);
    return 0;
  }

  int _addonsTotalPriceRub(List<Map<String, dynamic>> addons) {
    int sum = 0;
    for (final a in addons) {
      sum += _addonQty(a) * _addonPrice(a);
    }
    return sum;
  }

  int _addonsTotalDurationMin(List<Map<String, dynamic>> addons) {
    int sum = 0;
    for (final a in addons) {
      sum += _addonQty(a) * _addonDur(a);
    }
    return sum;
  }

  // ===== helpers =====

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

  Color _bayColor(BuildContext context, int? bayId) {
    final primary = Theme.of(context).colorScheme.primary;
    if (bayId == null) return primary;
    if (bayId == 1) return _greenLine;
    if (bayId == 2) return _blueLine;
    return primary;
  }

  String _bayLabel(int? bayId) {
    if (bayId == null) return 'Любая линия';
    if (bayId == 1) return 'Зелёная линия';
    if (bayId == 2) return 'Синяя линия';
    return 'Линия';
  }

  String _bayIconPath(int? bayId) {
    if (bayId == null) return _bayAnyIcon;
    if (bayId == 1) return _bayGreenIcon;
    if (bayId == 2) return _bayBlueIcon;
    return _bayAnyIcon;
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
    return const AssetImage('assets/images/services/kuzov_1080.jpg');
  }

  Color _statusColor(BuildContext context, Booking b) {
    if (b.isWashing) return Colors.blue;
    final cs = Theme.of(context).colorScheme;
    switch (b.status) {
      case BookingStatus.active:
        return cs.primary;
      case BookingStatus.pendingPayment:
        return Colors.orange;
      case BookingStatus.completed:
        return Colors.grey;
      case BookingStatus.canceled:
        return Colors.red;
    }
  }

  String _statusText(Booking b) {
    if (b.isWashing) return 'Моется';
    switch (b.status) {
      case BookingStatus.active:
        return 'Забронировано';
      case BookingStatus.pendingPayment:
        return 'Ожидает оплаты';
      case BookingStatus.completed:
        return 'Завершено';
      case BookingStatus.canceled:
        return 'Отменено';
    }
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

  bool _canPayDeposit(Booking b) {
    if (b.status != BookingStatus.pendingPayment) return false;
    final due = b.paymentDueAt;
    if (due == null) return true;
    return due.isAfter(DateTime.now());
  }

  int _effectivePriceRub(Service? service, Booking b, int addonsPriceRub) {
    final base = service?.priceRub ?? 0;
    return max(base + addonsPriceRub - b.discountRub, 0);
  }

  int _toPayRub(Service? service, Booking b, int addonsPriceRub) {
    final total = _effectivePriceRub(service, b, addonsPriceRub);
    return max(total - b.paidTotalRub, 0);
  }

  // ===== actions =====

  Future<void> _payNow({
    required Booking booking,
    required Service? service,
  }) async {
    if (_paying) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!_canPayDeposit(booking)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Оплата недоступна для этой записи.')),
      );
      return;
    }

    setState(() => _paying = true);

    try {
      final paid = await navigator.push<bool>(
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
          const SnackBar(content: Text('Оплата прошла. Запись подтверждена.')),
        );
        setState(() => _future = _load(forceRefresh: true, showNotify: false));
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

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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

    try {
      await widget.repo.cancelBooking(bookingId);
      if (!mounted) return;

      messenger.showSnackBar(const SnackBar(content: Text('Запись отменена')));
      setState(() {
        _canceling = false;
        _future = _load(forceRefresh: true, showNotify: false);
      });

      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _canceling = false);
      messenger.showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  // ===== UI blocks =====

  Widget _card({required Widget child}) {
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

  Widget _hero(Service? service) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(
          image: _serviceHero(service),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
            alignment: Alignment.center,
            child: Icon(Icons.local_car_wash, size: 36, color: cs.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _bayPill(int? bayId) {
    final cs = Theme.of(context).colorScheme;
    final stripe = _bayColor(context, bayId);
    final label = _bayLabel(bayId);
    final iconPath = _bayIconPath(bayId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 28,
            decoration: BoxDecoration(
              color: stripe,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Image.asset(
            iconPath,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: stripe,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.88),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addonsCard(List<Map<String, dynamic>> addons) {
    if (addons.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final sumRub = _addonsTotalPriceRub(addons);
    final sumMin = _addonsTotalDurationMin(addons);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Дополнительные услуги',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          ...addons.map((a) {
            final name = _addonName(a);
            final qty = _addonQty(a);
            final price = _addonPrice(a);
            final dur = _addonDur(a);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          qty > 1 ? '$name × $qty' : name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '+$price ₽',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+$dur мин',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            );
          }),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            'Итого по доп. услугам: $sumRub ₽ • +$sumMin мин',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

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
                child: FilledButton(
                  onPressed: () {
                    setState(
                      () => _future = _load(
                        forceRefresh: true,
                        showNotify: false,
                      ),
                    );
                  },
                  child: const Text('Повторить'),
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

          final addons = _addonsSafe(booking);
          final addonsPriceRub = _addonsTotalPriceRub(addons);

          final isCanceled = booking.status == BookingStatus.canceled;
          final isCompleted = booking.status == BookingStatus.completed;
          final canCancel = !(isCanceled || isCompleted);

          final showPayButton = _canPayDeposit(booking);

          final depositRub = booking.depositRub > 0
              ? booking.depositRub
              : _depositRubFallback;

          final total = _effectivePriceRub(service, booking, addonsPriceRub);
          final paidTotal = booking.paidTotalRub;
          final toPay = _toPayRub(service, booking, addonsPriceRub);

          final discountReason = (booking.discountNote ?? '').trim().isEmpty
              ? null
              : booking.discountNote!.trim();

          final badgeColor = _statusColor(context, booking);
          final badge = _badge(
            text: _statusText(booking).toUpperCase(),
            color: badgeColor,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _hero(service),
              const SizedBox(height: 12),

              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            service?.name ?? 'Услуга удалена',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        badge,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dtText(booking.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _bayPill(booking.bayId),
                    const SizedBox(height: 14),

                    Text(
                      'Стоимость: $total ₽',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    if (addons.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Доп. услуги: +${addons.length} (на ${_addonsTotalPriceRub(addons)} ₽)',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],

                    if (booking.discountRub > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Скидка: ${booking.discountRub} ₽',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (discountReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Причина скидки: $discountReason',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 10),
                    Text(
                      'Оплачено: $paidTotal ₽   К оплате: $toPay ₽',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    if (booking.status == BookingStatus.pendingPayment &&
                        booking.paymentDueAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Оплатить до: ${_dtText(booking.paymentDueAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.80),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      'Оплата брони: $depositRub ₽',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.80),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              if (addons.isNotEmpty) ...[
                const SizedBox(height: 12),
                _addonsCard(addons),
              ],

              if ((booking.comment ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Комментарий',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booking.comment!.trim(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withValues(alpha: 0.82),
                        ),
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
                    Text(
                      'Авто',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      car == null ? 'Авто удалено' : _carTitleForUi(car),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface.withValues(alpha: 0.88),
                      ),
                    ),
                    if (car != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        car.subtitle,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (showPayButton) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _paying
                        ? null
                        : () => _payNow(booking: booking, service: service),
                    icon: const Icon(Icons.credit_card),
                    label: Text(
                      _paying ? 'Оплачиваю...' : 'Оплатить $depositRub ₽',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
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
