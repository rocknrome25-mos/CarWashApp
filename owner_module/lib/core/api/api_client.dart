import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({required this.baseUrl});

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }

  Future<void> login({required String phone, required String password}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _token = json['token'] as String?;
    } else {
      throw Exception('Ошибка авторизации: ${response.body}');
    }
  }

  Future<void> logout() async {
    _token = null;
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );

    _checkResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(data),
    );

    _checkResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(data),
    );

    _checkResponse(response);
    return jsonDecode(response.body);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );

    _checkResponse(response);
    return jsonDecode(response.body);
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401) {
      _token = null;
      throw Exception('Не авторизован');
    }

    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
}