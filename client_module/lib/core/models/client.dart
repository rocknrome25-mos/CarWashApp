class Client {
  final String id;
  final String phone;
  final String? name;
  final String gender; // 'MALE' | 'FEMALE'
  final DateTime? birthDate;

  const Client({
    required this.id,
    required this.phone,
    this.name,
    required this.gender,
    this.birthDate,
  });

  factory Client.fromJson(Map<String, dynamic> j) {
    return Client(
      id: j['id'] as String,
      phone: (j['phone'] ?? '') as String,
      name: j['name'] as String?,
      gender: (j['gender'] ?? 'MALE') as String,
      birthDate: j['birthDate'] == null
          ? null
          : DateTime.parse(j['birthDate'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'gender': gender,
    'birthDate': birthDate?.toIso8601String(),
  };

  String get displayName {
    final n = (name ?? '').trim();
    return n.isEmpty ? phone : n;
  }
}
