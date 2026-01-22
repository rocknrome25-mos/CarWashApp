class AdminSession {
  final String userId;
  final String phone;
  final String? name;
  final String locationId;
  final String? activeShiftId;

  /// feature flags
  final Map<String, bool> featuresEnabled;

  AdminSession({
    required this.userId,
    required this.phone,
    required this.locationId,
    this.name,
    this.activeShiftId,
    Map<String, bool>? featuresEnabled,
  }) : featuresEnabled = featuresEnabled ?? const {};

  bool featureOn(String key, {bool defaultValue = true}) {
    return featuresEnabled[key] ?? defaultValue;
  }

  factory AdminSession.fromLoginJson(Map<String, dynamic> json, {Map<String, bool>? featuresEnabled}) {
    final user = json['user'] as Map<String, dynamic>;
    return AdminSession(
      userId: user['id'] as String,
      phone: user['phone'] as String,
      name: user['name'] as String?,
      locationId: user['locationId'] as String,
      activeShiftId: json['activeShiftId'] as String?,
      featuresEnabled: featuresEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'user': {
          'id': userId,
          'phone': phone,
          'name': name,
          'locationId': locationId,
        },
        'activeShiftId': activeShiftId,
        'featuresEnabled': featuresEnabled,
      };

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final fe = <String, bool>{};
    final raw = json['featuresEnabled'];
    if (raw is Map) {
      raw.forEach((k, v) {
        fe[k.toString()] = v == true;
      });
    }

    return AdminSession(
      userId: user['id'] as String,
      phone: user['phone'] as String,
      name: user['name'] as String?,
      locationId: user['locationId'] as String,
      activeShiftId: json['activeShiftId'] as String?,
      featuresEnabled: fe,
    );
  }

  AdminSession copyWith({String? activeShiftId, Map<String, bool>? featuresEnabled}) => AdminSession(
        userId: userId,
        phone: phone,
        name: name,
        locationId: locationId,
        activeShiftId: activeShiftId ?? this.activeShiftId,
        featuresEnabled: featuresEnabled ?? this.featuresEnabled,
      );
}
