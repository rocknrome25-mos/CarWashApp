import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';

class DemoRepository {
  final List<Car> _cars = [];
  final List<Service> _services = [];
  final List<Booking> _bookings = [];

  DemoRepository() {
    _services.addAll(const [
      Service(id: 's1', name: 'Мойка кузова', price: 1000, durationMinutes: 30),
      Service(
        id: 's2',
        name: 'Мойка + салон',
        price: 1800,
        durationMinutes: 60,
      ),
      Service(id: 's3', name: 'Детейлинг', price: 3500, durationMinutes: 120),
    ]);
  }

  List<Car> getCars() => List.unmodifiable(_cars);
  void addCar(Car car) => _cars.insert(0, car);

  List<Service> getServices() => List.unmodifiable(_services);

  List<Booking> getBookings() => List.unmodifiable(_bookings);
  void addBooking(Booking booking) => _bookings.insert(0, booking);
}
