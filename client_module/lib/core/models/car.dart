class Car {
  final String id;
  final String brand;
  final String model;
  final String plate;

  const Car({
    required this.id,
    required this.brand,
    required this.model,
    required this.plate,
  });

  String get title => '$brand $model';
}