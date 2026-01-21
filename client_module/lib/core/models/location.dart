class Location {
  final String id;
  final String name;
  final String address;
  final String colorHex;
  final int baysCount;

  const Location({
    required this.id,
    required this.name,
    required this.address,
    required this.colorHex,
    required this.baysCount,
  });

  factory Location.fromJson(Map<String, dynamic> j) {
    return Location(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      colorHex: (j['colorHex'] ?? '#2D9CDB').toString(),
      baysCount: (j['baysCount'] is num) ? (j['baysCount'] as num).toInt() : 2,
    );
  }
}
