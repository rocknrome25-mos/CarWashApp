enum BookingStatus { pendingPayment, active, canceled, completed }

BookingStatus bookingStatusFromJson(String v) {
  switch (v.toUpperCase()) {
    case 'PENDING_PAYMENT':
      return BookingStatus.pendingPayment;
    case 'ACTIVE':
      return BookingStatus.active;
    case 'CANCELED':
      return BookingStatus.canceled;
    case 'COMPLETED':
      return BookingStatus.completed;
    default:
      return BookingStatus.active;
  }
}

String bookingStatusToJson(BookingStatus s) {
  switch (s) {
    case BookingStatus.pendingPayment:
      return 'PENDING_PAYMENT';
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
  final String? cancelReason;

  final DateTime? paymentDueAt;
  final DateTime? paidAt;

  final String carId;
  final String serviceId;

  final int? bayId;

  // ✅ новое
  final String? comment;

  Booking({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.dateTime,
    required this.status,
    required this.carId,
    required this.serviceId,
    this.canceledAt,
    this.cancelReason,
    this.paymentDueAt,
    this.paidAt,
    this.bayId,
    this.comment,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final cancelReasonRaw = (json['cancelReason'] as String?)?.trim();
    final cancelReason = (cancelReasonRaw?.isEmpty ?? true) ? null : cancelReasonRaw;

    // comment может приходить по-разному — парсим мягко
    String? comment = (json['comment'] as String?) ??
        (json['clientComment'] as String?) ??
        (json['customerComment'] as String?) ??
        (json['notes'] as String?);
    comment = comment?.trim();
    if (comment != null && comment.isEmpty) comment = null;

    return Booking(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      dateTime: DateTime.parse(json['dateTime'] as String),
      status: bookingStatusFromJson((json['status'] ?? 'ACTIVE') as String),
      canceledAt: json['canceledAt'] == null ? null : DateTime.parse(json['canceledAt'] as String),
      cancelReason: cancelReason,
      paymentDueAt: json['paymentDueAt'] == null ? null : DateTime.parse(json['paymentDueAt'] as String),
      paidAt: json['paidAt'] == null ? null : DateTime.parse(json['paidAt'] as String),
      carId: json['carId'] as String,
      serviceId: json['serviceId'] as String,
      bayId: json['bayId'] is int ? json['bayId'] as int : int.tryParse('${json['bayId']}'),
      comment: comment,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'dateTime': dateTime.toIso8601String(),
        'status': bookingStatusToJson(status),
        'canceledAt': canceledAt?.toIso8601String(),
        'cancelReason': cancelReason,
        'paymentDueAt': paymentDueAt?.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'carId': carId,
        'serviceId': serviceId,
        'bayId': bayId,
        'comment': comment,
      };
}
