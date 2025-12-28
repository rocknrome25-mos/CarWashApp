import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';
import '../utils/normalize.dart';

class DemoRepository {
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

  List<Car> getCars() => List.unmodifiable(_cars);
  List<Service> getServices() => List.unmodifiable(_services);
  List<Booking> getBookings() => List.unmodifiable(_bookings);

  Car? findCar(String id) {
    for (final c in _cars) {
      if (c.id == id) return c;
    }
    return null;
  }

  Service? findService(String id) {
    for (final s in _services) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool plateExists(String plateNormalized) {
    final norm = plateNormalized.trim();
    if (norm.isEmpty) return false;
    return _cars.any((c) => c.plateNormalized == norm);
  }

  void addCar({
    required String make,
    required String model,
    required String plate,
    int? year,
    String? color,
    String? bodyType,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final plateNorm = normalizePlate(plate);
    _cars.add(
      Car(
        id: id,
        make: make.trim(),
        model: model.trim(),
        plateDisplay: plate.trim().toUpperCase(),
        plateNormalized: plateNorm,
        year: year,
        color: color,
        bodyType: bodyType,
      ),
    );
  }

  void deleteCar(String id) {
    _cars.removeWhere((c) => c.id == id);
    _bookings.removeWhere((b) => b.carId == id);
  }

  void addBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _bookings.add(
      Booking(id: id, carId: carId, serviceId: serviceId, dateTime: dateTime),
    );
    _bookings.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void deleteBooking(String id) {
    _bookings.removeWhere((b) => b.id == id);
  }
}
