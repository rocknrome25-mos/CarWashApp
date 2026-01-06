import '../data/app_repository.dart';
import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';
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

  Duration _paymentHold() => const Duration(minutes: 15);

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
    // демо “хаускипинг”: просроченные pending -> canceled
    final now = DateTime.now();
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
          canceledAt: now,
          cancelReason: 'PAYMENT_EXPIRED',
          paymentDueAt: b.paymentDueAt,
          paidAt: b.paidAt,
          carId: b.carId,
          serviceId: b.serviceId,
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
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final due = now.add(_paymentHold());

    final b = Booking(
      id: id,
      createdAt: now,
      updatedAt: now,
      canceledAt: null,
      cancelReason: null,
      paymentDueAt: due,
      paidAt: null,
      carId: carId,
      serviceId: serviceId,
      dateTime: dateTime,
      status: BookingStatus.pendingPayment,
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
      // в демо можно и throw, но оставим мягко
      return Booking(
        id: bookingId,
        createdAt: now,
        updatedAt: now,
        dateTime: now,
        status: BookingStatus.active,
        carId: '',
        serviceId: '',
        paidAt: now,
      );
    }

    final old = _bookings[idx];

    // если просрочено — считаем отмененным
    if (old.status == BookingStatus.pendingPayment &&
        old.paymentDueAt != null &&
        old.paymentDueAt!.isBefore(now)) {
      final canceled = Booking(
        id: old.id,
        createdAt: old.createdAt,
        updatedAt: now,
        dateTime: old.dateTime,
        status: BookingStatus.canceled,
        canceledAt: now,
        cancelReason: 'PAYMENT_EXPIRED',
        paymentDueAt: old.paymentDueAt,
        paidAt: old.paidAt,
        carId: old.carId,
        serviceId: old.serviceId,
      );
      _bookings[idx] = canceled;
      return canceled;
    }

    final updated = Booking(
      id: old.id,
      createdAt: old.createdAt,
      updatedAt: now,
      dateTime: old.dateTime,
      status: BookingStatus.active,
      canceledAt: null,
      cancelReason: null,
      paymentDueAt: old.paymentDueAt,
      paidAt: now,
      carId: old.carId,
      serviceId: old.serviceId,
    );

    _bookings[idx] = updated;
    return updated;
  }

  @override
  Future<Booking> cancelBooking(String id) async {
    final idx = _bookings.indexWhere((b) => b.id == id);
    final now = DateTime.now();

    if (idx == -1) {
      // в демо просто игнор, можно и throw
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
      paidAt: old.paidAt,
      carId: old.carId,
      serviceId: old.serviceId,
      dateTime: old.dateTime,
      status: BookingStatus.canceled,
    );

    _bookings[idx] = updated;
    return updated;
  }
}
