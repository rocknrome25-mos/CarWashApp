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
}
