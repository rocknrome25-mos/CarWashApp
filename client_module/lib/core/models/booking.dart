enum BookingStatus { active, canceled, completed }

BookingStatus bookingStatusFromJson(String v) {
  switch (v.toUpperCase()) {
    case 'ACTIVE':
      return BookingStatus.active;
    case 'CANCELED':
      return BookingStatus.canceled;
    case 'COMPLETED':
      return BookingStatus.completed;
    default:
      // безопасный дефолт
      return BookingStatus.active;
  }
}

String bookingStatusToJson(BookingStatus s) {
  switch (s) {
    case BookingStatus.active:
      return 'ACTIVE';
    case BookingStatus.canceled:
      return 'CANCELED';
    case BookingStatus.completed:
      return 'COMPLETED';
  }
}

class Booking {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dateTime;
  final BookingStatus status;
  final DateTime? canceledAt;
  final String carId;
  final String serviceId;

  Booking({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.dateTime,
    required this.status,
    required this.canceledAt,
    required this.carId,
    required this.serviceId,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dateTime: DateTime.parse(json['dateTime'] as String),
      status: bookingStatusFromJson((json['status'] ?? 'ACTIVE') as String),
      canceledAt: json['canceledAt'] == null
          ? null
          : DateTime.parse(json['canceledAt'] as String),
      carId: json['carId'] as String,
      serviceId: json['serviceId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'dateTime': dateTime.toIso8601String(),
        'status': bookingStatusToJson(status),
        'canceledAt': canceledAt?.toIso8601String(),
        'carId': carId,
        'serviceId': serviceId,
      };
}
