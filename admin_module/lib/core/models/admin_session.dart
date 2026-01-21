class AdminSession {
  final String userId;
  final String phone;
  final String? name;
  final String locationId;
  final String? activeShiftId;

  AdminSession({
    required this.userId,
    required this.phone,
    required this.locationId,
    this.name,
    this.activeShiftId,
  });

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AdminSession(
      userId: user['id'] as String,
      phone: user['phone'] as String,
      name: user['name'] as String?,
      locationId: user['locationId'] as String,
      activeShiftId: json['activeShiftId'] as String?,
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
  };

  AdminSession copyWith({String? activeShiftId}) => AdminSession(
    userId: userId,
    phone: phone,
    name: name,
    locationId: locationId,
    activeShiftId: activeShiftId,
  );
}
