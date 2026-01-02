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
    final list = includeCanceled
        ? _bookings
        : _bookings.where((b) => b.status == BookingStatus.active).toList();

    return List.unmodifiable(list);
  }

  @override
  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final b = Booking(
      id: id,
      carId: carId,
      serviceId: serviceId,
      dateTime: dateTime,
      status: BookingStatus.active,
    );

    _bookings.add(b);
    _bookings.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return b;
  }

  @override
  Future<Booking> cancelBooking(String id) async {
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx == -1) {
      // в демо просто игнор, можно и throw
      return Booking(
        id: id,
        carId: '',
        serviceId: '',
        dateTime: DateTime.now(),
        status: BookingStatus.canceled,
      );
    }

    final old = _bookings[idx];
    final updated = Booking(
      id: old.id,
      carId: old.carId,
      serviceId: old.serviceId,
      dateTime: old.dateTime,
      status: BookingStatus.canceled,
    );

    _bookings[idx] = updated;
    return updated;
  }
}
