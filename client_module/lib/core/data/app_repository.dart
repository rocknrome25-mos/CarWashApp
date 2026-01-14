import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';

abstract class AppRepository {
  Future<List<Service>> getServices({bool forceRefresh = false});

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

  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  });

  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
    int? bayId,

    // ✅ новое
    int? depositRub,
    int? bufferMin,
    String? comment,
  });

  Future<Booking> cancelBooking(String id);

  Future<Booking> payBooking({
    required String bookingId,
    String? method,
  });
}
