enum PaymentKind { deposit, remaining, extra, refund }

PaymentKind paymentKindFromJson(String v) {
  switch (v.toUpperCase()) {
    case 'DEPOSIT':
      return PaymentKind.deposit;
    case 'REMAINING':
      return PaymentKind.remaining;
    case 'EXTRA':
      return PaymentKind.extra;
    case 'REFUND':
      return PaymentKind.refund;
    default:
      return PaymentKind.deposit;
  }
}

String paymentKindToJson(PaymentKind k) {
  switch (k) {
    case PaymentKind.deposit:
      return 'DEPOSIT';
    case PaymentKind.remaining:
      return 'REMAINING';
    case PaymentKind.extra:
      return 'EXTRA';
    case PaymentKind.refund:
      return 'REFUND';
  }
}

class Payment {
  final String id;
  final String bookingId;
  final int amountRub;
  final String method;
  final PaymentKind kind;
  final DateTime paidAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amountRub,
    required this.method,
    required this.kind,
    required this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      amountRub: json['amountRub'] is int
          ? json['amountRub'] as int
          : int.tryParse('${json['amountRub']}') ?? 0,
      method: (json['method'] as String?) ?? '',
      kind: paymentKindFromJson((json['kind'] ?? 'DEPOSIT') as String),
      paidAt: DateTime.parse(json['paidAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingId': bookingId,
    'amountRub': amountRub,
    'method': method,
    'kind': paymentKindToJson(kind),
    'paidAt': paidAt.toIso8601String(),
  };
}
