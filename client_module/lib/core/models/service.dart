class Service {
  final String id;
  final String name;
  final int priceRub;
  final int? durationMin;

  /// Optional (production): backend can provide full URL to image
  final String? imageUrl;

  /// Optional: description for details page
  final String? description;

  const Service({
    required this.id,
    required this.name,
    required this.priceRub,
    this.durationMin,
    this.imageUrl,
    this.description,
  });

  factory Service.fromJson(Map<String, dynamic> j) {
    return Service(
      id: j['id'] as String,
      name: j['name'] as String,
      priceRub: j['priceRub'] as int,
      durationMin: j['durationMin'] as int?,
      imageUrl: j['imageUrl'] as String?,
      description: j['description'] as String?,
    );
  }
}
