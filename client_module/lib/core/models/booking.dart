enum BookingStatus { active, canceled }

BookingStatus bookingStatusFromApi(String s) {
  return (s == 'CANCELED') ? BookingStatus.canceled : BookingStatus.active;
}

String bookingStatusToApi(BookingStatus s) {
  return (s == BookingStatus.canceled) ? 'CANCELED' : 'ACTIVE';
}

class Booking {
  final String id;
  final String carId;
  final String serviceId;
  final DateTime dateTime;
  final BookingStatus status;

  const Booking({
    required this.id,
    required this.carId,
    required this.serviceId,
    required this.dateTime,
    required this.status,
  });

  factory Booking.fromJson(Map<String, dynamic> j) {
    return Booking(
      id: j['id'] as String,
      carId: j['carId'] as String,
      serviceId: j['serviceId'] as String,
      dateTime: DateTime.parse(j['dateTime'] as String),
      status: bookingStatusFromApi((j['status'] ?? 'ACTIVE') as String),
    );
  }
}
