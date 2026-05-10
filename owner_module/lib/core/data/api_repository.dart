import '../api/api_client.dart';
import '../cache/memory_cache.dart';
import '../models/user.dart';
import '../models/service.dart';
import '../models/alert.dart';
import '../models/location.dart';
import 'app_repository.dart';

class ApiRepository implements AppRepository {
  final ApiClient api;
  final MemoryCache cache;

  ApiRepository({required this.api, required this.cache});

  // Auth methods
  @override
  Future<void> login({required String phone, required String password}) async {
    await api.login(phone: phone, password: password);
  }

  @override
  Future<void> logout() async {
    await api.logout();
  }

  // User methods
  @override
  Future<List<User>> getUsers({bool forceRefresh = false}) async {
    const key = 'users';

    if (!forceRefresh) {
      final cached = cache.get<List<User>>(key);
      if (cached != null) return cached;
    }

    final json = await api.get('/users');
    final users = (json as List)
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();

    cache.set(key, users);
    return users;
  }

  @override
  Future<User> getUser(String id) async {
    final json = await api.get('/users/$id');
    return User.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<User> createUser({
    required User user,
    required String password,
  }) async {
    final json = await api.post(
      '/users',
      data: {...user.toJson(), 'password': password},
    );

    final newUser = User.fromJson(json as Map<String, dynamic>);
    cache.invalidate('users');
    return newUser;
  }

  @override
  Future<User> updateUser(User user) async {
    final json = await api.put('/users/${user.id}', data: user.toJson());

    final updatedUser = User.fromJson(json as Map<String, dynamic>);
    cache.invalidate('users');
    return updatedUser;
  }

  @override
  Future<void> deleteUser(String id) async {
    await api.delete('/users/$id');
    cache.invalidate('users');
  }

  @override
  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    await api.post(
      '/users/$userId/reset-password',
      data: {'newPassword': newPassword},
    );
  }

  // Service methods
  @override
  Future<List<Service>> getServices({bool forceRefresh = false}) async {
    const key = 'services';

    if (!forceRefresh) {
      final cached = cache.get<List<Service>>(key);
      if (cached != null) return cached;
    }

    final json = await api.get('/services');
    final services = (json as List)
        .map((item) => Service.fromJson(item as Map<String, dynamic>))
        .toList();

    cache.set(key, services);
    return services;
  }

  @override
  Future<Service> getService(String id) async {
    final json = await api.get('/services/$id');
    return Service.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Service> createService(Service service) async {
    final json = await api.post('/services', data: service.toJson());

    final newService = Service.fromJson(json as Map<String, dynamic>);
    cache.invalidate('services');
    return newService;
  }

  @override
  Future<Service> updateService(Service service) async {
    final json = await api.put(
      '/services/${service.id}',
      data: service.toJson(),
    );

    final updatedService = Service.fromJson(json as Map<String, dynamic>);
    cache.invalidate('services');
    return updatedService;
  }

  @override
  Future<void> deleteService(String id) async {
    await api.delete('/services/$id');
    cache.invalidate('services');
  }

  // Alert methods
  @override
  Future<List<Alert>> getAlerts({bool forceRefresh = false}) async {
    const key = 'alerts';

    if (!forceRefresh) {
      final cached = cache.get<List<Alert>>(key);
      if (cached != null) return cached;
    }

    final json = await api.get('/alerts');
    final alerts = (json as List)
        .map((item) => Alert.fromJson(item as Map<String, dynamic>))
        .toList();

    cache.set(key, alerts);
    return alerts;
  }

  @override
  Future<Alert> getAlert(String id) async {
    final json = await api.get('/alerts/$id');
    return Alert.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Alert> createAlert(Alert alert) async {
    final json = await api.post('/alerts', data: alert.toJson());

    final newAlert = Alert.fromJson(json as Map<String, dynamic>);
    cache.invalidate('alerts');
    return newAlert;
  }

  @override
  Future<Alert> updateAlert(Alert alert) async {
    final json = await api.put('/alerts/${alert.id}', data: alert.toJson());

    final updatedAlert = Alert.fromJson(json as Map<String, dynamic>);
    cache.invalidate('alerts');
    return updatedAlert;
  }

  @override
  Future<void> deleteAlert(String id) async {
    await api.delete('/alerts/$id');
    cache.invalidate('alerts');
  }

  // Location methods
  @override
  Future<List<Location>> getLocations({bool forceRefresh = false}) async {
    const key = 'locations';

    if (!forceRefresh) {
      final cached = cache.get<List<Location>>(key);
      if (cached != null) return cached;
    }

    final json = await api.get('/locations');
    final locations = (json as List)
        .map((item) => Location.fromJson(item as Map<String, dynamic>))
        .toList();

    cache.set(key, locations);
    return locations;
  }

  @override
  Future<Location> getLocation(String id) async {
    final json = await api.get('/locations/$id');
    return Location.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Location> createLocation(Location location) async {
    final json = await api.post('/locations', data: location.toJson());

    final newLocation = Location.fromJson(json as Map<String, dynamic>);
    cache.invalidate('locations');
    return newLocation;
  }

  @override
  Future<Location> updateLocation(Location location) async {
    final json = await api.put(
      '/locations/${location.id}',
      data: location.toJson(),
    );

    final updatedLocation = Location.fromJson(json as Map<String, dynamic>);
    cache.invalidate('locations');
    return updatedLocation;
  }

  @override
  Future<void> deleteLocation(String id) async {
    await api.delete('/locations/$id');
    cache.invalidate('locations');
  }

  // Dispose method
  @override
  void dispose() {
    cache.clear();
  }
}
