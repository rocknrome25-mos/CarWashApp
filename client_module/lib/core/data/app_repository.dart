import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';
import '../models/client.dart';

abstract class AppRepository {
  // --- SESSION ---
  Client? get currentClient;
  Future<void> setCurrentClient(Client c);
  Future<void> logout();

  // --- AUTH/REGISTER ---
  Future<Client> registerClient({
    required String phone,
    String? name,
    required String gender, // MALE/FEMALE
    DateTime? birthDate,
  });

  /// Для демо (пока): "demo / 1234" создаёт/ставит тестового клиента
  Future<Client> loginDemo({String phone});

  // --- SERVICES ---
  Future<List<Service>> getServices({bool forceRefresh = false});

  // --- CARS ---
  Future<List<Car>> getCars({bool forceRefresh = false});

  Future<Car> addCar({
    required String makeDisplay,
    required String modelDisplay,
    required String plateDisplay,
    int? year,
    String? color,
    String? bodyType,
  });

  Future<void> deleteCar(String id);

  // --- BOOKINGS ---
  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  });

  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
    int? bayId,
    int? depositRub,
    int? bufferMin,
    String? comment,
  });

  Future<Booking> payBooking({required String bookingId, String? method});

  Future<Booking> cancelBooking(String id);
}
