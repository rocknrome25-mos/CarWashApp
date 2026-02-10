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
    if (d is Map) return d.cast<String, dynamic>();
    throw Exception('$opName failed: unexpected response');
  }

  List<dynamic> _decodeList(http.Response res, String opName) {
    if (res.statusCode >= 400) {
      throw Exception('$opName failed: ${res.statusCode} ${res.body}');
    }
    final d = jsonDecode(res.body);
    if (d is List) return d;
    if (d is Map<String, dynamic>) return [d];
    if (d is Map) return [d.cast<String, dynamic>()];
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

  // ===== WAITLIST =====

  Future<List<dynamic>> waitlistDay(
    String userId,
    String shiftId,
    String ymd,
  ) async {
    final res = await http
        .get(
          _u('/admin/waitlist/day', {'date': ymd}),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);
    return _decodeList(res, 'waitlist');
  }

  Future<Map<String, dynamic>> convertWaitlistToBooking(
    String userId,
    String shiftId,
    String waitlistId, {
    int? bayId,
    String? dateTimeIso,
  }) async {
    final payload = <String, dynamic>{
      if (bayId != null) 'bayId': bayId,
      if (dateTimeIso != null && dateTimeIso.trim().isNotEmpty)
        'dateTime': dateTimeIso.trim(),
    };

    final res = await http
        .post(
          _u('/admin/waitlist/$waitlistId/convert'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'waitlist convert');
  }

  Future<Map<String, dynamic>> deleteWaitlist(
    String userId,
    String shiftId,
    String waitlistId, {
    String? reason,
  }) async {
    final wid = waitlistId.trim();
    if (wid.isEmpty) throw Exception('waitlistId is required');

    final payload = <String, dynamic>{
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    final req = http.Request('DELETE', _u('/admin/waitlist/$wid'));
    req.headers.addAll(_jsonHeaders(userId: userId, shiftId: shiftId));
    req.body = jsonEncode(payload);

    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);

    return _decodeMap(res, 'waitlist delete');
  }

  // ===== PUBLIC BUSY SLOTS (NO ADMIN HEADERS) =====
  Future<List<dynamic>> publicBusySlots({
    required String locationId,
    required int bayId,
    required String fromIsoUtc,
    required String toIsoUtc,
  }) async {
    final res = await http
        .get(
          _u('/bookings/busy', {
            'locationId': locationId,
            'bayId': bayId.toString(),
            'from': fromIsoUtc,
            'to': toIsoUtc,
          }),
          headers: _jsonHeaders(),
        )
        .timeout(_timeout);

    return _decodeList(res, 'busy slots');
  }

  // ===== SERVICES (single source of truth) =====
  // GET /services?locationId=...&kind=BASE|ADDON
  Future<List<dynamic>> services({
    required String locationId,
    String? kind, // 'BASE' | 'ADDON'
    bool includeInactive = false,
  }) async {
    final loc = locationId.trim();
    if (loc.isEmpty) throw Exception('locationId is required');

    final q = <String, String>{'locationId': loc};
    final k = (kind ?? '').trim().toUpperCase();
    if (k == 'BASE' || k == 'ADDON') q['kind'] = k;
    if (includeInactive) q['includeInactive'] = 'true';

    final res = await http
        .get(_u('/services', q), headers: _jsonHeaders())
        .timeout(_timeout);
    return _decodeList(res, 'services');
  }

  // ===== BAYS =====

  Future<List<dynamic>> listBays(String userId, String shiftId) async {
    final res = await http
        .get(
          _u('/admin/bays'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);
    return _decodeList(res, 'list bays');
  }

  Future<Map<String, dynamic>> setBayActive(
    String userId,
    String shiftId, {
    required int bayNumber,
    required bool isActive,
    String? reason,
  }) async {
    final path = isActive
        ? '/admin/bays/$bayNumber/open'
        : '/admin/bays/$bayNumber/close';

    String? body;
    if (!isActive) {
      final r = (reason ?? '').trim();
      if (r.isEmpty) throw Exception('Причина закрытия обязательна');
      body = jsonEncode({'reason': r});
    } else {
      body = null;
    }

    final res = await http
        .post(
          _u(path),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: body,
        )
        .timeout(_timeout);

    return _decodeMap(res, isActive ? 'open bay' : 'close bay');
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

  // ===== ADMIN PAY / DISCOUNT / ADDONS / PHOTOS / CASH =====
  // (оставлено как у тебя — без изменений)

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

  Future<Map<String, dynamic>> adminApplyDiscount(
    String userId,
    String shiftId,
    String bookingId, {
    required int discountRub,
    required String reason,
  }) async {
    final payload = <String, dynamic>{
      'discountRub': discountRub,
      'reason': reason.trim(),
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

  Future<List<dynamic>> listBookingAddons(
    String userId,
    String shiftId,
    String bookingId,
  ) async {
    final res = await http
        .get(
          _u('/admin/bookings/$bookingId/addons'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);
    return _decodeList(res, 'list addons');
  }

  Future<Map<String, dynamic>> addBookingAddon(
    String userId,
    String shiftId,
    String bookingId, {
    required String serviceId,
    int qty = 1,
  }) async {
    final payload = <String, dynamic>{
      'serviceId': serviceId.trim(),
      'qty': qty,
    };

    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/addons'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'add addon');
  }

  Future<Map<String, dynamic>> removeBookingAddon(
    String userId,
    String shiftId,
    String bookingId, {
    required String serviceId,
  }) async {
    final res = await http
        .delete(
          _u('/admin/bookings/$bookingId/addons/${serviceId.trim()}'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'remove addon');
  }

  Future<List<dynamic>> listBookingPhotos(
    String userId,
    String shiftId,
    String bookingId,
  ) async {
    final res = await http
        .get(
          _u('/admin/bookings/$bookingId/photos'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
        )
        .timeout(_timeout);
    return _decodeList(res, 'list photos');
  }

  Future<Map<String, dynamic>> addBookingPhoto(
    String userId,
    String shiftId,
    String bookingId, {
    required String kind,
    required String url,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'kind': kind.trim(),
      'url': url.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final res = await http
        .post(
          _u('/admin/bookings/$bookingId/photos'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'add photo');
  }

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

  // ===== ADMIN MANUAL BOOKING =====
  Future<Map<String, dynamic>> createAdminBooking(
    String userId,
    String shiftId, {
    required String locationId,
    required int bayId,
    required String dateTimeIsoUtc,
    required String clientName,
    required String clientPhone,
    required String carPlate,
    String? bodyType,
    required String serviceId,
    List<Map<String, dynamic>>? addons, // [{serviceId, qty}]
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'locationId': locationId.trim(),
      'bayId': bayId,
      'dateTime': dateTimeIsoUtc.trim(),
      'source': 'ADMIN_PHONE',
      'createdBy': 'ADMIN',

      'client': {'name': clientName.trim(), 'phone': clientPhone.trim()},
      'car': {
        'plate': carPlate.trim(),
        if (bodyType != null && bodyType.trim().isNotEmpty)
          'bodyType': bodyType.trim(),
      },

      // ✅ canonical: base service + addons
      'serviceId': serviceId.trim(),
      if (addons != null && addons.isNotEmpty) 'addons': addons,

      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };

    final res = await http
        .post(
          _u('/admin/bookings/manual'),
          headers: _jsonHeaders(userId: userId, shiftId: shiftId),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    return _decodeMap(res, 'admin create booking');
  }
}
