import 'dart:convert';

enum BookingStatus { active, pendingPayment, completed, canceled }

BookingStatus _parseStatus(dynamic v) {
  final s = (v ?? '').toString().toLowerCase().trim();
  switch (s) {
    case 'active':
      return BookingStatus.active;
    case 'pending_payment':
    case 'pendingpayment':
    case 'pending':
      return BookingStatus.pendingPayment;
    case 'completed':
      return BookingStatus.completed;
    case 'canceled':
    case 'cancelled':
      return BookingStatus.canceled;
    default:
      // безопасный дефолт
      return BookingStatus.active;
  }
}

int _int(dynamic v, {int fallback = 0}) {
  if (v is num) return v.toInt();
  return int.tryParse((v ?? '').toString()) ?? fallback;
}

bool _bool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  final s = (v ?? '').toString().toLowerCase().trim();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _parseAddons(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v.where((e) => e != null).map((e) {
      if (e is Map) return e.cast<String, dynamic>();
      try {
        final m = jsonDecode(e.toString());
        if (m is Map) return m.cast<String, dynamic>();
      } catch (_) {}
      return <String, dynamic>{'raw': e.toString()};
    }).toList();
  }
  if (v is Map) {
    // на всякий случай, если сервер отдаст объект вместо массива
    return [v.cast<String, dynamic>()];
  }
  return const [];
}

class Booking {
  final String id;

  final String carId;
  final String serviceId;
  final DateTime dateTime;

  final String? locationId;
  final int? bayId;

  final BookingStatus status;
  final bool isWashing;

  final int depositRub;
  final int paidTotalRub;
  final int discountRub;
  final String? discountNote;

  final String? comment;

  final DateTime? paymentDueAt;
  final DateTime? lastPaidAt;

  /// ✅ NEW: addons as returned by backend
  /// Example item:
  /// { serviceId, qty, priceRubSnapshot, durationMinSnapshot, service?: {name,...} }
  final List<Map<String, dynamic>> addons;

  const Booking({
    required this.id,
    required this.carId,
    required this.serviceId,
    required this.dateTime,
    this.locationId,
    this.bayId,
    required this.status,
    required this.isWashing,
    required this.depositRub,
    required this.paidTotalRub,
    required this.discountRub,
    this.discountNote,
    this.comment,
    this.paymentDueAt,
    this.lastPaidAt,
    this.addons = const [],
  });

  factory Booking.fromJson(Map<String, dynamic> j) {
    return Booking(
      id: (j['id'] ?? '').toString(),
      carId: (j['carId'] ?? j['car_id'] ?? '').toString(),
      serviceId: (j['serviceId'] ?? j['service_id'] ?? '').toString(),
      dateTime: DateTime.parse(
        (j['dateTime'] ?? j['date_time']).toString(),
      ).toLocal(),
      locationId: (j['locationId'] ?? j['location_id'])?.toString(),
      bayId: j['bayId'] == null ? null : _int(j['bayId']),
      status: _parseStatus(j['status']),
      isWashing: _bool(j['isWashing']),
      depositRub: _int(j['depositRub']),
      paidTotalRub: _int(j['paidTotalRub']),
      discountRub: _int(j['discountRub']),
      discountNote: (j['discountNote'] ?? '').toString().trim().isEmpty
          ? null
          : (j['discountNote'] ?? '').toString(),
      comment: (j['comment'] ?? '').toString().trim().isEmpty
          ? null
          : (j['comment'] ?? '').toString(),
      paymentDueAt: _dt(j['paymentDueAt']),
      lastPaidAt: _dt(j['lastPaidAt']),
      addons: _parseAddons(j['addons']),
    );
  }
}
