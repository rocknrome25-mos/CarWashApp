class Service {
  final String id;
  final String name;
  final int priceRub;
  final int? durationMin;

  const Service({
    required this.id,
    required this.name,
    required this.priceRub,
    this.durationMin,
  });

  factory Service.fromJson(Map<String, dynamic> j) {
    return Service(
      id: j['id'] as String,
      name: j['name'] as String,
      priceRub: j['priceRub'] as int,
      durationMin: j['durationMin'] as int?,
    );
  }
}
