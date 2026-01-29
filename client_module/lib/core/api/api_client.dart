import 'dart:convert';
import 'package:http/http.dart' as http;

/// A clean API exception designed for UI.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Object? details;
  final String? raw;

  ApiException(this.statusCode, this.message, {this.details, this.raw});

  @override
  String toString() => message;
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

  /// ✅ FIX: query реально передаём в URI
  Future<dynamic> deleteJson(String path, {Map<String, String>? query}) async {
    final res = await _http.delete(_u(path, query));
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    final text = res.body;
    final contentType = res.headers['content-type'] ?? '';
    final isJson = contentType.contains('application/json');

    // OK
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (!isJson) return text;
      return text.isEmpty ? null : jsonDecode(text);
    }

    // ERROR
    Object? details;
    final String? raw = text.isEmpty ? null : text;

    String msg = _defaultMessageForStatus(res.statusCode);

    if (isJson && text.isNotEmpty) {
      try {
        final j = jsonDecode(text);
        details = j;

        if (j is Map) {
          final m = j['message'];

          if (m is String && m.trim().isNotEmpty) {
            msg = m.trim();
          } else if (m is List && m.isNotEmpty) {
            msg = m.map((e) => e.toString()).join('\n');
          } else if (j['error'] is String &&
              (j['error'] as String).isNotEmpty) {
            msg = (j['error'] as String).trim();
          }
        } else {
          msg = j.toString();
        }
      } catch (_) {
        msg = raw ?? msg;
      }
    } else if (text.isNotEmpty) {
      msg = text;
    }

    msg = _humanizeMessage(res.statusCode, msg);
    msg = _sanitizeForUi(msg);

    throw ApiException(res.statusCode, msg, details: details, raw: raw);
  }

  String _defaultMessageForStatus(int code) {
    switch (code) {
      case 400:
        return 'Некорректные данные';
      case 401:
        return 'Не авторизован';
      case 403:
        return 'Нет доступа';
      case 404:
        return 'Не найдено';
      case 409:
        return 'Конфликт данных';
      case 422:
        return 'Ошибка валидации';
      case 500:
      case 502:
      case 503:
        return 'Ошибка сервера';
      default:
        return 'Ошибка запроса';
    }
  }

  String _humanizeMessage(int code, String msg) {
    final m = msg.toLowerCase();

    // ✅ WAITLIST when bays are closed (server throws 409 BAY_CLOSED_WAITLISTED)
    if (code == 409 && m.contains('bay_closed_waitlisted')) {
      return 'Посты сейчас закрыты. Мы добавили вас в очередь ожидания и свяжемся, когда появится возможность.';
    }

    // ✅ Payment expired housekeeping
    if (code == 409 &&
        (m.contains('payment deadline expired') ||
            m.contains('payment_expired'))) {
      return 'Время оплаты истекло. Запись отменена.';
    }

    if (code == 409 &&
        (m.contains('cannot delete car') ||
            (m.contains('delete') && m.contains('car'))) &&
        (m.contains('active') || m.contains('booking'))) {
      return 'Нельзя удалить авто: есть активные записи. Сначала отмените записи.';
    }

    if ((code == 400 || code == 422) &&
        (m.contains('cannot cancel a past booking') ||
            (m.contains('cannot cancel') && m.contains('past')))) {
      return 'Нельзя отменить прошедшую запись.';
    }

    if ((code == 400 || code == 422) &&
        (m.contains('cannot cancel a started booking') ||
            (m.contains('cannot cancel') && m.contains('started')))) {
      return 'Нельзя отменить запись, которая уже началась.';
    }

    if (code == 409 &&
        (m.contains('completed booking') ||
            (m.contains('cannot cancel') && m.contains('completed')))) {
      return 'Нельзя отменить завершённую запись.';
    }

    if (code == 409) {
      if (m.contains('slot') ||
          m.contains('busy') ||
          m.contains('already booked') ||
          m.contains('занят') ||
          m.contains('время уже занято')) {
        return 'Выбранное время уже занято. Выбери другой слот.';
      }
      if (m.contains('duplicate') || m.contains('unique')) {
        return 'Такое значение уже существует.';
      }
      return 'Конфликт: данные изменились. Обнови список и попробуй снова.';
    }

    if (code == 404) {
      if (m.contains('booking')) return 'Запись не найдена.';
      if (m.contains('car')) return 'Авто не найдено (возможно, удалено).';
      if (m.contains('service'))
        return 'Услуга не найдена (возможно, удалена).';
      return 'Ресурс не найден.';
    }

    if (code == 400 || code == 422) {
      if (m.contains('date') || m.contains('time') || m.contains('datetime')) {
        return 'Некорректная дата/время. Проверь и попробуй снова.';
      }
      return msg;
    }

    return msg;
  }

  String _sanitizeForUi(String msg) {
    var out = msg.trim();
    out = out.replaceAll(RegExp(r'ApiException\(\d+\):\s*'), '');
    if (out.isEmpty) out = 'Ошибка запроса';
    return out;
  }
}
