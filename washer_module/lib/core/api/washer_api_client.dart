import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/washer_session_store.dart';

class WasherApiException implements Exception {
  final int status;
  final String message;
  final dynamic raw;

  WasherApiException(this.status, this.message, {this.raw});

  @override
  String toString() => 'WasherApiException($status): $message';
}

class WasherApiClient {
  final String baseUrl;
  final WasherSessionStore store;

  WasherApiClient({required this.baseUrl, required this.store});

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth && store.userId != null) {
      h['x-user-id'] = store.userId!;
    }
    return h;
  }

  Never _throwFrom(http.Response r) {
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {
      body = r.body;
    }
    final msg = (body is Map && body['message'] != null)
        ? body['message'].toString()
        : 'HTTP ${r.statusCode}';
    throw WasherApiException(r.statusCode, msg, raw: body);
  }

  Future<Map<String, dynamic>> login(String phone) async {
    final uri = Uri.parse('$baseUrl/washer/login');
    final r = await http.post(
      uri,
      headers: _headers(auth: false),
      body: jsonEncode({'phone': phone}),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) _throwFrom(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentShift() async {
    final uri = Uri.parse('$baseUrl/washer/shift/current');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode < 200 || r.statusCode >= 300) _throwFrom(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentShiftBookings() async {
    final uri = Uri.parse('$baseUrl/washer/shift/current/bookings');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode < 200 || r.statusCode >= 300) _throwFrom(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clockIn() async {
    final uri = Uri.parse('$baseUrl/washer/clock-in');
    final r = await http.post(uri, headers: _headers(), body: jsonEncode({}));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwFrom(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clockOut() async {
    final uri = Uri.parse('$baseUrl/washer/clock-out');
    final r = await http.post(uri, headers: _headers(), body: jsonEncode({}));
    if (r.statusCode < 200 || r.statusCode >= 300) _throwFrom(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stats({
    required DateTime from,
    required DateTime to,
  }) async {
    final qs = {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    };
    final uri = Uri.parse('$baseUrl/washer/stats').replace(queryParameters: qs);
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode < 200 || r.statusCode >= 300) _throwFrom(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
