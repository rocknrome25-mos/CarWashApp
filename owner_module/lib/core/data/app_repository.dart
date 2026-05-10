import '../models/user.dart';
import '../models/service.dart';
import '../models/alert.dart';
import '../models/location.dart';

abstract class AppRepository {
  // Auth methods
  Future<void> login({required String phone, required String password});
  Future<void> logout();

  // User methods
  Future<List<User>> getUsers({bool forceRefresh = false});
  Future<User> getUser(String id);
  Future<User> createUser({required User user, required String password});
  Future<User> updateUser(User user);
  Future<void> deleteUser(String id);
  Future<void> resetUserPassword({
    required String userId,
    required String newPassword,
  });

  // Service methods
  Future<List<Service>> getServices({bool forceRefresh = false});
  Future<Service> getService(String id);
  Future<Service> createService(Service service);
  Future<Service> updateService(Service service);
  Future<void> deleteService(String id);

  // Alert methods
  Future<List<Alert>> getAlerts({bool forceRefresh = false});
  Future<Alert> getAlert(String id);
  Future<Alert> createAlert(Alert alert);
  Future<Alert> updateAlert(Alert alert);
  Future<void> deleteAlert(String id);

  // Location methods
  Future<List<Location>> getLocations({bool forceRefresh = false});
  Future<Location> getLocation(String id);
  Future<Location> createLocation(Location location);
  Future<Location> updateLocation(Location location);
  Future<void> deleteLocation(String id);

  // Dispose method
  void dispose();
}
