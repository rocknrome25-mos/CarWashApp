import 'package:shared_preferences/shared_preferences.dart';

class WasherSessionStore {
  static const _kUserId = 'washer_user_id';
  static const _kPhone = 'washer_phone';
  static const _kName = 'washer_name';
  static const _kLocationId = 'washer_location_id';

  String? userId;
  String? phone;
  String? name;
  String? locationId;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    userId = sp.getString(_kUserId);
    phone = sp.getString(_kPhone);
    name = sp.getString(_kName);
    locationId = sp.getString(_kLocationId);
  }

  Future<void> save({
    required String userId,
    required String phone,
    required String? name,
    required String locationId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUserId, userId);
    await sp.setString(_kPhone, phone);
    await sp.setString(_kLocationId, locationId);
    if (name != null) {
      await sp.setString(_kName, name);
    } else {
      await sp.remove(_kName);
    }

    this.userId = userId;
    this.phone = phone;
    this.name = name;
    this.locationId = locationId;
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserId);
    await sp.remove(_kPhone);
    await sp.remove(_kName);
    await sp.remove(_kLocationId);

    userId = null;
    phone = null;
    name = null;
    locationId = null;
  }
}
