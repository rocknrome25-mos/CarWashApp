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
    // server usually sends UTC ISO; we show local
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _parseAddons(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v.where((e) => e != null).map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      try {
        final m = jsonDecode(e.toString());
        if (m is Map) return Map<String, dynamic>.from(m);
      } catch (_) {}
      return <String, dynamic>{'raw': e.toString()};
    }).toList();
  }
  if (v is Map) {
    return [Map<String, dynamic>.from(v)];
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

  /// ✅ Source-of-truth timestamps (often present even if isWashing отсутствует)
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// ✅ Backward compatible (UI expects bool)
  /// We compute it from startedAt/finishedAt unless server explicitly provides isWashing.
  final bool isWashing;

  final int depositRub;
  final int paidTotalRub;
  final int discountRub;
  final String? discountNote;

  final String? comment;

  final DateTime? paymentDueAt;
  final DateTime? lastPaidAt;

  final List<Map<String, dynamic>> addons;

  const Booking({
    required this.id,
    required this.carId,
    required this.serviceId,
    required this.dateTime,
    this.locationId,
    this.bayId,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
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
    final status = _parseStatus(j['status']);

    final startedAt = _dt(j['startedAt'] ?? j['started_at']);
    final finishedAt = _dt(j['finishedAt'] ?? j['finished_at']);

    // If backend sends explicit isWashing -> trust it.
    // Otherwise derive from timestamps.
    final explicitIsWashing =
        j.containsKey('isWashing') || j.containsKey('is_washing');
    final isWashing = explicitIsWashing
        ? _bool(j['isWashing'] ?? j['is_washing'])
        : (startedAt != null &&
              finishedAt == null &&
              status != BookingStatus.canceled &&
              status != BookingStatus.completed);

    // dateTime can be dateTime or date_time
    final dtRaw = (j['dateTime'] ?? j['date_time'] ?? '').toString();
    final dateTime = DateTime.parse(dtRaw).toLocal();

    // bay can be bayId or bay_id
    final bayVal = j['bayId'] ?? j['bay_id'];
    final bayId = bayVal == null ? null : _int(bayVal);

    final discountNoteRaw = (j['discountNote'] ?? j['discount_note'] ?? '')
        .toString();
    final commentRaw = (j['comment'] ?? '').toString();

    return Booking(
      id: (j['id'] ?? '').toString(),
      carId: (j['carId'] ?? j['car_id'] ?? '').toString(),
      serviceId: (j['serviceId'] ?? j['service_id'] ?? '').toString(),
      dateTime: dateTime,
      locationId: (j['locationId'] ?? j['location_id'])?.toString(),
      bayId: bayId,
      status: status,
      startedAt: startedAt,
      finishedAt: finishedAt,
      isWashing: isWashing,
      depositRub: _int(j['depositRub'] ?? j['deposit_rub']),
      paidTotalRub: _int(j['paidTotalRub'] ?? j['paid_total_rub']),
      discountRub: _int(j['discountRub'] ?? j['discount_rub']),
      discountNote: discountNoteRaw.trim().isEmpty ? null : discountNoteRaw,
      comment: commentRaw.trim().isEmpty ? null : commentRaw,
      paymentDueAt: _dt(j['paymentDueAt'] ?? j['payment_due_at']),
      lastPaidAt: _dt(j['lastPaidAt'] ?? j['last_paid_at']),
      addons: _parseAddons(j['addons']),
    );
  }
}
