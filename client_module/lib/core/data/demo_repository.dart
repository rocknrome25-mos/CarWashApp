import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';

class BookingDetails {
  final Booking booking;
  final Car? car;
  final Service? service;

  BookingDetails({
    required this.booking,
    required this.car,
    required this.service,
  });
}

class DemoRepository {
  final List<Car> _cars = [];

  final Set<String> _protectedServiceIds = {'s1', 's2', 's3'};

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

  Booking? findBooking(String id) {
    for (final b in _bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  BookingDetails? getBookingDetails(String bookingId) {
    final b = findBooking(bookingId);
    if (b == null) return null;

    return BookingDetails(
      booking: b,
      car: findCar(b.carId),
      service: findService(b.serviceId),
    );
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

  bool isServiceProtected(String id) => _protectedServiceIds.contains(id);

  void addService({
    required String name,
    required int priceRub,
    required int durationMin,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _services.add(
      Service(
        id: id,
        name: name.trim(),
        priceRub: priceRub,
        durationMin: durationMin,
      ),
    );
  }

  bool deleteService(String id) {
    if (isServiceProtected(id)) return false;
    _services.removeWhere((s) => s.id == id);
    _bookings.removeWhere((b) => b.serviceId == id);
    return true;
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
