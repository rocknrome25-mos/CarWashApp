import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminApiClient {
  final String baseUrl;
  AdminApiClient({required this.baseUrl});

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

  Future<Map<String, dynamic>> adminLogin(String phone) async {
    final res = await http.post(
      _u('/admin/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({'phone': phone}),
    );
    if (res.statusCode >= 400) {
      throw Exception('login failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConfig(String locationId) async {
    final res = await http.get(
      _u('/config', {'locationId': locationId}),
      headers: _jsonHeaders(),
    );
    if (res.statusCode >= 400) {
      throw Exception('config failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> openShift(String userId) async {
    final res = await http.post(
      _u('/admin/shifts/open'),
      headers: _jsonHeaders(userId: userId),
    );
    if (res.statusCode >= 400) {
      throw Exception('open shift failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeShift(String userId, String shiftId) async {
    final res = await http.post(
      _u('/admin/shifts/close'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
    );
    if (res.statusCode >= 400) {
      throw Exception('close shift failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> calendarDay(
    String userId,
    String shiftId,
    String ymd,
  ) async {
    final res = await http.get(
      _u('/admin/calendar/day', {'date': ymd}),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
    );
    if (res.statusCode >= 400) {
      throw Exception('calendar failed: ${res.statusCode} ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    return [decoded];
  }

  Future<Map<String, dynamic>> startBooking(
    String userId,
    String shiftId,
    String bookingId,
    String? adminNote,
  ) async {
    final res = await http.post(
      _u('/admin/bookings/$bookingId/start'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
      body: jsonEncode({'adminNote': adminNote}),
    );
    if (res.statusCode >= 400) {
      throw Exception('start failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
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
    final res = await http.post(
      _u('/admin/bookings/$bookingId/move'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
      body: jsonEncode({
        'newDateTime': newDateTimeIso,
        'newBayId': newBayId,
        'reason': reason,
        'clientAgreed': clientAgreed,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('move failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> finishBooking(
    String userId,
    String shiftId,
    String bookingId,
    String? adminNote,
  ) async {
    final res = await http.post(
      _u('/admin/bookings/$bookingId/finish'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
      body: jsonEncode({'adminNote': adminNote}),
    );
    if (res.statusCode >= 400) {
      throw Exception('finish failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ===== CASH =====
  Future<void> cashOpenFloat(
    String userId,
    String shiftId,
    int amountRub, {
    String? note,
  }) async {
    final res = await http.post(
      _u('/admin/cash/open-float'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
      body: jsonEncode({'amountRub': amountRub, 'note': note}),
    );
    if (res.statusCode >= 400) {
      throw Exception('cash open-float failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Map<String, dynamic>> cashExpected(
    String userId,
    String shiftId,
  ) async {
    final res = await http.get(
      _u('/admin/cash/expected'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
    );
    if (res.statusCode >= 400) {
      throw Exception('cash expected failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> cashClose(
    String userId,
    String shiftId, {
    required int countedRub,
    required int handoverRub,
    required int keepRub,
    String? note,
  }) async {
    final res = await http.post(
      _u('/admin/cash/close'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
      body: jsonEncode({
        'countedRub': countedRub,
        'handoverRub': handoverRub,
        'keepRub': keepRub,
        'note': note,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('cash close failed: ${res.statusCode} ${res.body}');
    }
  }
Future<Map<String, dynamic>> adminPayBooking(
    String userId,
    String shiftId,
    String bookingId, {
    required String kind, // DEPOSIT/REMAINING/EXTRA/REFUND
    required int amountRub,
    required String methodType, // CASH/CARD/CONTRACT
    String? methodLabel,
    String? note,
  }) async {
    final res = await http.post(
      _u('/admin/bookings/$bookingId/pay'),
      headers: _jsonHeaders(userId: userId, shiftId: shiftId),
      body: jsonEncode({
        'kind': kind,
        'amountRub': amountRub,
        'methodType': methodType,
        'methodLabel': methodLabel,
        'note': note,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('admin pay failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }}
