import '../api/api_client.dart';
import '../cache/memory_cache.dart';
import '../data/app_repository.dart';
import '../models/booking.dart';
import '../models/car.dart';
import '../models/service.dart';

class ApiAppRepository implements AppRepository {
  final ApiClient api;
  final MemoryCache cache;

  ApiAppRepository({required this.api, required this.cache});

  // ---- SERVICES ----
  @override
  Future<List<Service>> getServices({bool forceRefresh = false}) async {
    const key = 'services';
    if (!forceRefresh) {
      final cached = cache.get<List<Service>>(key);
      if (cached != null) return cached;
    }

    final data = await api.getJson('/services') as List;
    final list = data
        .map((e) => Service.fromJson(e as Map<String, dynamic>))
        .toList();

    cache.set(key, list, ttl: const Duration(minutes: 2));
    return list;
  }

  // ---- CARS ----
  @override
  Future<List<Car>> getCars({bool forceRefresh = false}) async {
    const key = 'cars';
    if (!forceRefresh) {
      final cached = cache.get<List<Car>>(key);
      if (cached != null) return cached;
    }

    final data = await api.getJson('/cars') as List;
    final list = data
        .map((e) => Car.fromJson(e as Map<String, dynamic>))
        .toList();

    cache.set(key, list, ttl: const Duration(seconds: 30));
    return list;
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
    final j =
        await api.postJson('/cars', {
              'makeDisplay': makeDisplay.trim(),
              'modelDisplay': modelDisplay.trim(),
              'plateDisplay': plateDisplay.trim(),
              'year': year,
              'color': (color == null || color.trim().isEmpty)
                  ? null
                  : color.trim(),
              'bodyType': (bodyType == null || bodyType.trim().isEmpty)
                  ? null
                  : bodyType.trim(),
            })
            as Map<String, dynamic>;

    cache.invalidate('cars');
    return Car.fromJson(j);
  }

  @override
  Future<void> deleteCar(String id) async {
    await api.deleteJson('/cars/$id');
    cache.invalidate('cars');
    // на всякий случай — списки записей тоже могли зависеть от авто
    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
  }

  // ---- BOOKINGS ----
  @override
  Future<List<Booking>> getBookings({
    bool includeCanceled = false,
    bool forceRefresh = false,
  }) async {
    final key = includeCanceled ? 'bookings_all' : 'bookings_active';

    if (!forceRefresh) {
      final cached = cache.get<List<Booking>>(key);
      if (cached != null) return cached;
    }

    final data =
        await api.getJson(
              '/bookings',
              query: includeCanceled ? {'includeCanceled': 'true'} : null,
            )
            as List;

    final list = data
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();

    cache.set(key, list, ttl: const Duration(seconds: 15));
    return list;
  }

  @override
  Future<Booking> createBooking({
    required String carId,
    required String serviceId,
    required DateTime dateTime,
  }) async {
    final j =
        await api.postJson('/bookings', {
              'carId': carId,
              'serviceId': serviceId,
              'dateTime': dateTime.toUtc().toIso8601String(),
            })
            as Map<String, dynamic>;

    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    return Booking.fromJson(j);
  }

  @override
  Future<Booking> cancelBooking(String id) async {
    final j = await api.deleteJson('/bookings/$id') as Map<String, dynamic>;

    cache.invalidate('bookings_all');
    cache.invalidate('bookings_active');
    return Booking.fromJson(j);
  }
}
