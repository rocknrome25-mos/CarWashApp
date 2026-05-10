class Location {
  final String id;
  final String name;
  final String? address;
  final bool? isActive;
  final String? phone;
  final String? email;
  final String? description;

  Location({
    required this.id,
    required this.name,
    this.address,
    this.isActive,
    this.phone,
    this.email,
    this.description,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      isActive: json['isActive'] as bool?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'isActive': isActive,
      'phone': phone,
      'email': email,
      'description': description,
    };
  }

  Location copyWith({
    String? id,
    String? name,
    String? address,
    bool? isActive,
    String? phone,
    String? email,
    String? description,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description: description ?? this.description,
    );
  }
}