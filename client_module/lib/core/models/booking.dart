import 'payment.dart';

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

  final String locationId;

  final DateTime dateTime;
  final BookingStatus status;

  final DateTime? startedAt;
  final DateTime? finishedAt;

  final DateTime? canceledAt;
  final String? cancelReason;

  final DateTime? paymentDueAt;

  final String carId;
  final String serviceId;

  final int? bayId;

  final String? comment;

  // ✅ из API
  final int depositRub;
  final int bufferMin;

  // ✅ скидка (из admin)
  final int discountRub;
  final String? discountNote;

  // ✅ платежи
  final List<Payment> payments;

  Booking({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.locationId,
    required this.dateTime,
    required this.status,
    required this.carId,
    required this.serviceId,
    required this.depositRub,
    required this.bufferMin,
    this.startedAt,
    this.finishedAt,
    this.canceledAt,
    this.cancelReason,
    this.paymentDueAt,
    this.bayId,
    this.comment,
    this.discountRub = 0,
    this.discountNote,
    this.payments = const [],
  });

  bool get isWashing =>
      status == BookingStatus.active && startedAt != null && finishedAt == null;

  int get paidTotalRub {
    var sum = 0;
    for (final p in payments) {
      if (p.kind == PaymentKind.refund) {
        sum -= p.amountRub;
      } else {
        sum += p.amountRub;
      }
    }
    return sum;
  }

  DateTime? get lastPaidAt {
    if (payments.isEmpty) return null;
    final sorted = [...payments]..sort((a, b) => a.paidAt.compareTo(b.paidAt));
    return sorted.last.paidAt;
  }

  bool get isDepositPaid =>
      payments.any((p) => p.kind == PaymentKind.deposit && p.amountRub > 0);

  factory Booking.fromJson(Map<String, dynamic> json) {
    final cancelReasonRaw = (json['cancelReason'] as String?)?.trim();
    final cancelReason =
        (cancelReasonRaw?.isEmpty ?? true) ? null : cancelReasonRaw;

    String? comment =
        (json['comment'] as String?) ??
        (json['clientComment'] as String?) ??
        (json['customerComment'] as String?) ??
        (json['notes'] as String?);
    comment = comment?.trim();
    if (comment != null && comment.isEmpty) comment = null;

    final rawPayments = (json['payments'] as List?) ?? const [];
    final payments = rawPayments
        .whereType<Map<String, dynamic>>()
        .map((e) => Payment.fromJson(e))
        .toList();

    final discountRub = json['discountRub'] is int
        ? json['discountRub'] as int
        : int.tryParse('${json['discountRub']}') ?? 0;

    final discountNoteRaw = (json['discountNote'] as String?)?.trim();
    final discountNote =
        (discountNoteRaw?.isEmpty ?? true) ? null : discountNoteRaw;

    return Booking(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      locationId: (json['locationId'] ?? '').toString(),
      dateTime: DateTime.parse(json['dateTime'] as String),
      status: bookingStatusFromJson((json['status'] ?? 'ACTIVE') as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
      canceledAt: json['canceledAt'] == null
          ? null
          : DateTime.parse(json['canceledAt'] as String),
      cancelReason: cancelReason,
      paymentDueAt: json['paymentDueAt'] == null
          ? null
          : DateTime.parse(json['paymentDueAt'] as String),
      carId: json['carId'] as String,
      serviceId: json['serviceId'] as String,
      bayId: json['bayId'] is int
          ? json['bayId'] as int
          : int.tryParse('${json['bayId']}'),
      comment: comment,
      depositRub: json['depositRub'] is int
          ? json['depositRub'] as int
          : int.tryParse('${json['depositRub']}') ?? 0,
      bufferMin: json['bufferMin'] is int
          ? json['bufferMin'] as int
          : int.tryParse('${json['bufferMin']}') ?? 0,
      discountRub: discountRub,
      discountNote: discountNote,
      payments: payments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'locationId': locationId,
        'dateTime': dateTime.toIso8601String(),
        'status': bookingStatusToJson(status),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'canceledAt': canceledAt?.toIso8601String(),
        'cancelReason': cancelReason,
        'paymentDueAt': paymentDueAt?.toIso8601String(),
        'carId': carId,
        'serviceId': serviceId,
        'bayId': bayId,
        'comment': comment,
        'depositRub': depositRub,
        'bufferMin': bufferMin,
        'discountRub': discountRub,
        'discountNote': discountNote,
        'payments': payments.map((p) => p.toJson()).toList(),
      };
}
