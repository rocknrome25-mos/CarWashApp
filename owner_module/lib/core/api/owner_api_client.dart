import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class OwnerApiClient {
  final String baseUrl;

  OwnerApiClient({String? baseUrl})
    : baseUrl = (baseUrl == null || baseUrl.trim().isEmpty)
          ? AppConfig.defaultBaseUrl
          : baseUrl.trim();

  static const _timeout = Duration(seconds: 20);

  Uri _u(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final res = await http.get(_u('/health')).timeout(_timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = res.body.trim();

        if (body.isEmpty) {
          return {'status': 'warning'};
        }

        try {
          final decoded = jsonDecode(body);

          if (decoded is Map<String, dynamic>) {
            if (decoded['ok'] == true ||
                decoded['status'] == 'ok' ||
                decoded['status'] == 'healthy') {
              return {'status': 'ok'};
            }

            return {'status': 'warning', 'data': decoded};
          }

          return {'status': 'warning'};
        } catch (_) {
          return {'status': 'warning'};
        }
      }

      return {'status': 'error'};
    } catch (_) {
      return {'status': 'error'};
    }
  }

  Future<Map<String, dynamic>> getOwnerSummary({required String period}) async {
    final res = await http
        .get(_u('/owner/summary', {'period': period}))
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Owner summary request failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Owner summary response is not an object');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getOwnerChart({required String period}) async {
    final res = await http
        .get(_u('/owner/chart', {'period': period}))
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Owner chart request failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Owner chart response is not an object');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getOwnerFinance({required String period}) async {
    final res = await http
        .get(_u('/owner/finance', {'period': period}))
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Owner finance request failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Owner finance response is not an object');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getOwnerSuspiciousEvents({
    required String period,
    String? type,
    String? userId,
    int? limit,
  }) async {
    final query = <String, String>{'period': period};

    final safeType = (type ?? '').trim();
    final safeUserId = (userId ?? '').trim();

    if (safeType.isNotEmpty) {
      query['type'] = safeType;
    }

    if (safeUserId.isNotEmpty) {
      query['userId'] = safeUserId;
    }

    if (limit != null && limit > 0) {
      query['limit'] = '$limit';
    }

    final res = await http
        .get(_u('/owner/suspicious-events', query))
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Owner suspicious events request failed: ${res.statusCode}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Owner suspicious events response is not an object');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getOwnerEmployeeAnalytics({
    required String period,
  }) async {
    final res = await http
        .get(_u('/owner/employees/analytics', {'period': period}))
        .timeout(_timeout);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'Owner employee analytics request failed: ${res.statusCode}',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Owner employee analytics response is not an object');
    }

    return decoded;
  }
}
