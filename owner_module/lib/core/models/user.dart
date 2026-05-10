class User {
  final String id;
  final String phone;
  final String? email;
  final String displayName;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.phone,
    this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ?? json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'washer',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'displayName': displayName,
      'role': role,
      'isActive': isActive,
    };
  }

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? displayName,
    String? role,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}