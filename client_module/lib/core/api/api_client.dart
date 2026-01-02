import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final res = await _http.get(_u(path, query));
    return _handle(res);
  }

  Future<dynamic> postJson(String path, Object body) async {
    final res = await _http.post(
      _u(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> deleteJson(String path) async {
    final res = await _http.delete(_u(path));
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    final text = res.body;
    final isJson =
        res.headers['content-type']?.contains('application/json') ?? false;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (!isJson) return text;
      return text.isEmpty ? null : jsonDecode(text);
    }

    // try parse Prisma/Nest error
    String msg = 'Request failed';
    if (isJson && text.isNotEmpty) {
      final j = jsonDecode(text);
      msg = (j is Map && j['message'] != null) ? j['message'].toString() : text;
    } else if (text.isNotEmpty) {
      msg = text;
    }
    throw ApiException(res.statusCode, msg);
  }
}
