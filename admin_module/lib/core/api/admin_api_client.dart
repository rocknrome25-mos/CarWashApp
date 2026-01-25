import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminApiClient {
  final String baseUrl;
  AdminApiClient({required this.baseUrl});

  static const _timeout = Duration(seconds: 12);

  Uri _u(String path, [Map<String, String>? q]) {
    final uri = Uri.parse(baseUrl + path);
    return q == null ? uri : uri.replace(queryParameters: q);
  }

  Map<String, String> _jsonHeaders({String? userId, String? shiftId}) {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (userId != null) h['x-user-id'] = userId;
    if (shiftId != null) h['x-shift-id'] = shiftId;
    return h;
  }

  Map<String, dynamic> _decodeMap(http.Response res, String opName) {
    if (res.statusCode >= 400) {
      throw Exception('$opName failed: ${res.statusCode} ${res.body}');
    }
    final d = jsonDecode(res.body);
    if (d is Map<String, dynamic>) return d;
    throw Exception('$opName failed: unexpected response');
  }

  List<dynamic> _decodeList(http.Response res, String opName) {
    if (res.statusCode >= 400) {
      throw Exception('$opName failed: ${res.statusCode} ${res.body}');
    }
    final d = jsonDecode(res.body);
    if (d is List) return d;
    if (d is Map<String, dynamic>) return [d];
    throw Exception('$opName failed: unexpected response');
  }

  // ===== CONFIG =====

  Future<Map<String, dynamic>> getConfig(String locationId) async {
    final res = await http
        .get(_u('/config', {'locationId': locationId}), headers: _jsonHeaders())
        .timeout(_timeout);
    return _decodeMap(res, 'config');
  }

  // ===== AUTH =====

  Future<Map<String, dynamic>> adminLogin(String phone) async {
    final res = await http
        .post(
          _u('/admin/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({'phone': phone}),
        )
        .timeout(_timeout);
    return _decodeMap(res, 'login');
  }

  // ===== SHIFT =====

  Future<Map<String, dynamic>> openShift(String userId) async {
    final res = await http
        .post(_u('/admin/shifts/open'), headers: _jsonHeaders(userId: userId))
        .timeout(_timeout);
    return _decodeMap(res, 'open shift');
  }

  Future<Map<String, dynamic>> closeShift(String userId, String shiftId) async {
    final res = await http
        .post(
          _u('/admin/shifts/close'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);
    return _decodeMap(res, 'close shift');
  }

  // ===== CALENDAR =====

  Future<List<dynamic>> calendarDay(
    String userId,
    String shiftId,
    String ymd,
  ) async {
    final res = await http
        .get(
          _u('/admin/calendar/day', {'date': ymd}),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);
    return _decodeList(res, 'calendar');
  }

  // ===== BOOKINGS =====

  Future<Map<String, dynamic>> startBooking(
    String userId,
    String shiftId,
    String bookingId,
    String? adminNote,
  ) async {
    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/start'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode({'adminNote': adminNote}),
        )
        .timeout(_timeout);
    return _decodeMap(res, 'start');
  }

  Future<Map<String, dynamic>> finishBooking(
    String userId,
    String shiftId,
    String bookingId,
    String? adminNote,
  ) async {
    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/finish'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode({'adminNote': adminNote}),
        )
        .timeout(_timeout);
    return _decodeMap(res, 'finish');
  }

  Future<Map<String, dynamic>> moveBooking(
    String userId,
    String shiftId,
    String bookingId, {
    required String newDateTimeIso,
    required int newBayId,
    required String reason,
    required bool clientAgreed,
  }) async {
    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/move'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode({
            'newDateTime': newDateTimeIso,
            'newBayId': newBayId,
            'reason': reason,
            'clientAgreed': clientAgreed,
          }),
        )
        .timeout(_timeout);
    return _decodeMap(res, 'move');
  }

  // ===== ADMIN PAY =====

  Future<Map<String, dynamic>> adminPayBooking(
    String userId,
    String shiftId,
    String bookingId, {
    required String kind,
    required int amountRub,
    required String methodType,
    String? methodLabel,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'kind': kind,
      'amountRub': amountRub,
      'methodType': methodType,
      if (methodLabel != null && methodLabel.trim().isNotEmpty)
        'methodLabel': methodLabel.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/pay'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'admin pay');
  }

  // ===== ADMIN DISCOUNT =====

  Future<Map<String, dynamic>> adminApplyDiscount(
    String userId,
    String shiftId,
    String bookingId, {
    required int discountRub,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'discountRub': discountRub,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/discount'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'admin discount');
  }

  // ===== CASH =====

  Future<void> cashOpenFloat(
    String userId,
    String shiftId,
    int amountRub, {
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'amountRub': amountRub,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final res = await http
        .post(
          _u('/admin/cash/open-float'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (res.statusCode >= 400) {
      throw Exception('cash open-float failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> cashIn(
    String userId,
    String shiftId,
    int amountRub, {
    required String note,
  }) async {
    final res = await http
        .post(
          _u('/admin/cash/in'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode({'amountRub': amountRub, 'note': note.trim()}),
        )
        .timeout(_timeout);

    if (res.statusCode >= 400) {
      throw Exception('cash in failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> cashOut(
    String userId,
    String shiftId,
    int amountRub, {
    required String note,
  }) async {
    final res = await http
        .post(
          _u('/admin/cash/out'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode({'amountRub': amountRub, 'note': note.trim()}),
        )
        .timeout(_timeout);

    if (res.statusCode >= 400) {
      throw Exception('cash out failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Map<String, dynamic>> cashExpected(
    String userId,
    String shiftId,
  ) async {
    final res = await http
        .get(
          _u('/admin/cash/expected'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'cash expected');
  }

  Future<Map<String, dynamic>> cashSummary(
    String userId,
    String shiftId,
  ) async {
    final res = await http
        .get(
          _u('/admin/cash/summary'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'cash summary');
  }

  Future<void> cashClose(
    String userId,
    String shiftId, {
    required int countedRub,
    required int handoverRub,
    required int keepRub,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'countedRub': countedRub,
      'handoverRub': handoverRub,
      'keepRub': keepRub,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final res = await http
        .post(
          _u('/admin/cash/close'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (res.statusCode >= 400) {
      throw Exception('cash close failed: ${res.statusCode} ${res.body}');
    }
  }
}
