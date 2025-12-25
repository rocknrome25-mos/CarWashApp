import 'car.dart';
import 'service.dart';

class Booking {
  final String id;
  final Car car;
  final Service service;
  final DateTime startAt;
  final String status;

  Booking({
    required this.id,
    required this.car,
    required this.service,
    required this.startAt,
    this.status = 'pending',
  });
}
