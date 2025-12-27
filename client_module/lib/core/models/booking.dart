class Booking {
  final String id;
  final String carId;
  final String serviceId;
  final DateTime dateTime;

  const Booking({
    required this.id,
    required this.carId,
    required this.serviceId,
    required this.dateTime,
  });
}
