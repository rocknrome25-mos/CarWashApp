enum PaymentKind { deposit, remaining, refund, other }

PaymentKind paymentKindFromJson(String v) {
  switch (v.toUpperCase()) {
    case 'DEPOSIT':
      return PaymentKind.deposit;
    case 'REMAINING':
      return PaymentKind.remaining;
    case 'REFUND':
      return PaymentKind.refund;
    case 'OTHER':
    default:
      return PaymentKind.other;
  }
}

String paymentKindToJson(PaymentKind k) {
  switch (k) {
    case PaymentKind.deposit:
      return 'DEPOSIT';
    case PaymentKind.remaining:
      return 'REMAINING';
    case PaymentKind.refund:
      return 'REFUND';
    case PaymentKind.other:
      return 'OTHER';
  }
}

class Payment {
  final String id;
  final DateTime createdAt;
  final DateTime paidAt;
  final int amountRub;
  final String? method;
  final PaymentKind kind;
  final String bookingId;

  const Payment({
    required this.id,
    required this.createdAt,
    required this.paidAt,
    required this.amountRub,
    required this.kind,
    required this.bookingId,
    this.method,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    int intOr(int def, dynamic v) {
      if (v == null) return def;
      if (v is int) return v;
      return int.tryParse('$v') ?? def;
    }

    return Payment(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: DateTime.parse((json['paidAt'] ?? json['createdAt']) as String),
      amountRub: intOr(0, json['amountRub']),
      method: (json['method'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['method'] as String?)?.trim(),
      kind: paymentKindFromJson((json['kind'] ?? 'OTHER') as String),
      bookingId: json['bookingId'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'paidAt': paidAt.toIso8601String(),
    'amountRub': amountRub,
    'method': method,
    'kind': paymentKindToJson(kind),
    'bookingId': bookingId,
  };
}
