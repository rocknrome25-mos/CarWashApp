import '../data/app_repository.dart';
import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';
import '../models/payment.dart';
import '../utils/normalize.dart';

class DemoRepository implements AppRepository {
  final List<Car> _cars = [];

  final List<Service> _services = [
    const Service(
      id: 's1',
      name: 'Экспресс мойка',
      priceRub: 800,
      durationMin: 20,
    ),
    const Service(id: 's2', name: 'Комплекс', priceRub: 1500, durationMin: 45),
    const Service(
      id: 's3',
      name: 'Химчистка салона',
      priceRub: 6000,
      durationMin: 180,
    ),
  ];

  final List<Booking> _bookings = [];

  // демо-правила
  Duration _paymentHold() => const Duration(minutes: 15);
  static const int _defaultDepositRub = 500;
  static const int _defaultBufferMin = 15;

  // ---- SERVICES ----
  @override
  Future<List<Service>> getServices({bool forceRefresh = false}) async {
    return List.unmodifiable(_services);
  }

  // ---- CARS ----
  @override
  Future<List<Car>> getCars({bool forceRefresh = false}) async {
    return List.unmodifiable(_cars);
  }

  bool plateExists(String plateNormalized) {
    final norm = plateNormalized.trim();
    if (norm.isEmpty) return false;
    return _cars.any((c) => c.plateNormalized == norm);
  }

  @override
  Future<Car> addCar({
    required String makeDisplay,
    required String modelDisplay,
    required String plateDisplay,
    int? year,
    String? color,
    String? bodyType,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final plateNorm = normalizePlate(plateDisplay);

    final car = Car(
      id: id,
      make: makeDisplay.trim(),
      model: modelDisplay.trim(),
      plateDisplay: plateDisplay.trim().toUpperCase(),
      plateNormalized: plateNorm,
      year: year,
      color: color,
      bodyType: bodyType,
    );

    _cars.add(car);
    return car;
  }

  @override
  Future<void> deleteCar(String id) async {
    _cars.removeWhere((c) => c.id == id);
    _bookings.removeWhere((b) => b.carId == id);
  }

  // ---- BOOKINGS ----
  @override
  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();

    // демо-хаускипинг: просроченные pending -> canceled
    for (var i = 0; i < _bookings.length; i++) {
      final b = _bookings[i];

      if (b.status == BookingStatus.pendingPayment &&
          b.paymentDueAt != null &&
          b.paymentDueAt!.isBefore(now)) {
        _bookings[i] = Booking(
          id: b.id,
          createdAt: b.createdAt,
          updatedAt: now,
          dateTime: b.dateTime,
          status: BookingStatus.canceled,
          bayId: b.bayId,
          bufferMin: b.bufferMin,
          depositRub: b.depositRub,
          canceledAt: now,
          cancelReason: 'PAYMENT_EXPIRED',
          paymentDueAt: b.paymentDueAt,
          carId: b.carId,
          serviceId: b.serviceId,
          comment: b.comment,
          payments: b.payments,
        );
      }
    }

    final list = includeCanceled
        ? _bookings
        : _bookings.where((b) => b.status != BookingStatus.canceled).toList();

    return List.unmodifiable(list);
  }

  @override
  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
    int? bayId,
    int? depositRub,
    int? bufferMin,
    String? comment,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final due = now.add(_paymentHold());

    final dep = depositRub ?? _defaultDepositRub;
    final buf = bufferMin ?? _defaultBufferMin;

    final b = Booking(
      id: id,
      createdAt: now,
      updatedAt: now,
      canceledAt: null,
      cancelReason: null,
      paymentDueAt: due,
      carId: carId,
      serviceId: serviceId,
      dateTime: dateTime,
      status: BookingStatus.pendingPayment,
      bayId: bayId ?? 1,
      depositRub: dep,
      bufferMin: buf,
      comment: (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
      payments: const [],
    );

    _bookings.add(b);
    _bookings.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return b;
  }

  @override
  Future<Booking> payBooking({
    required String bookingId,
    String? method,
  }) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    final now = DateTime.now();

    if (idx == -1) {
      // fallback демо
      return Booking(
        id: bookingId,
        createdAt: now,
        updatedAt: now,
        dateTime: now,
        status: BookingStatus.active,
        carId: '',
        serviceId: '',
        depositRub: _defaultDepositRub,
        bufferMin: _defaultBufferMin,
        payments: const [],
      );
    }

    final old = _bookings[idx];

    // если истёк дедлайн — отменяем
    if (old.status == BookingStatus.pendingPayment &&
        old.paymentDueAt != null &&
        old.paymentDueAt!.isBefore(now)) {
      final canceled = Booking(
        id: old.id,
        createdAt: old.createdAt,
        updatedAt: now,
        dateTime: old.dateTime,
        status: BookingStatus.canceled,
        bayId: old.bayId,
        bufferMin: old.bufferMin,
        depositRub: old.depositRub,
        canceledAt: now,
        cancelReason: 'PAYMENT_EXPIRED',
        paymentDueAt: old.paymentDueAt,
        carId: old.carId,
        serviceId: old.serviceId,
        comment: old.comment,
        payments: old.payments,
      );
      _bookings[idx] = canceled;
      return canceled;
    }

    // добавляем платеж депозит (если ещё нет)
    final hasDeposit = old.payments.any((p) => p.kind == PaymentKind.deposit);
    final newPayments = [...old.payments];

    if (!hasDeposit) {
      newPayments.add(
        Payment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          bookingId: old.id,
          amountRub: (old.depositRub > 0) ? old.depositRub : _defaultDepositRub,
          method: (method?.trim().isNotEmpty ?? false)
              ? method!.trim()
              : 'CARD_TEST',
          kind: PaymentKind.deposit,
          paidAt: now,
        ),
      );
    }

    final updated = Booking(
      id: old.id,
      createdAt: old.createdAt,
      updatedAt: now,
      dateTime: old.dateTime,
      status: BookingStatus.active,
      bayId: old.bayId,
      bufferMin: old.bufferMin,
      depositRub: old.depositRub,
      canceledAt: null,
      cancelReason: null,
      paymentDueAt: null, // ✅ после оплаты дедлайн убираем
      carId: old.carId,
      serviceId: old.serviceId,
      comment: old.comment,
      payments: newPayments,
    );

    _bookings[idx] = updated;
    return updated;
  }

  @override
  Future<Booking> cancelBooking(String id) async {
    final idx = _bookings.indexWhere((b) => b.id == id);
    final now = DateTime.now();

    if (idx == -1) {
      return Booking(
        id: id,
        createdAt: now,
        updatedAt: now,
        canceledAt: now,
        dateTime: now,
        status: BookingStatus.canceled,
        cancelReason: 'NOT_FOUND_DEMO',
        carId: '',
        serviceId: '',
        depositRub: _defaultDepositRub,
        bufferMin: _defaultBufferMin,
        payments: const [],
      );
    }

    final old = _bookings[idx];
    final updated = Booking(
      id: old.id,
      createdAt: old.createdAt,
      updatedAt: now,
      canceledAt: now,
      cancelReason: old.status == BookingStatus.pendingPayment
          ? 'USER_CANCELED_PENDING'
          : 'USER_CANCELED',
      paymentDueAt: old.paymentDueAt,
      carId: old.carId,
      serviceId: old.serviceId,
      dateTime: old.dateTime,
      status: BookingStatus.canceled,
      bayId: old.bayId,
      bufferMin: old.bufferMin,
      depositRub: old.depositRub,
      comment: old.comment,
      payments: old.payments,
    );

    _bookings[idx] = updated;
    return updated;
  }
}
