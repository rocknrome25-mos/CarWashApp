import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';

class DemoRepository {
  final List<Car> _cars = [];

  final List<Service> _services = const [
    Service(id: 's1', name: 'Экспресс мойка', priceRub: 800, durationMin: 20),
    Service(id: 's2', name: 'Комплекс', priceRub: 1500, durationMin: 45),
    Service(
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

  void addCar({
    required String brand,
    required String model,
    required String plate,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _cars.add(
      Car(
        id: id,
        brand: brand.trim(),
        model: model.trim(),
        plate: plate.trim().toUpperCase(),
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
