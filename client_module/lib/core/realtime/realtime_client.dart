import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:web_socket_channel/web_socket_channel.dart';

class BookingRealtimeEvent {
  final String type; // e.g. 'booking.changed'
  final String locationId;
  final int bayId;
  final DateTime at;

  BookingRealtimeEvent({
    required this.type,
    required this.locationId,
    required this.bayId,
    required this.at,
  });

  static String _str(dynamic v) => (v ?? '').toString();

  static int _int(dynamic v, {int fallback = 1}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final n = int.tryParse(_str(v));
    return n ?? fallback;
  }

  static DateTime _dt(dynamic v) {
    final s = _str(v);
    final parsed = DateTime.tryParse(s);
    return parsed ?? DateTime.now().toUtc();
  }

  factory BookingRealtimeEvent.fromJson(Map<String, dynamic> j) {
    // Support "type" and "event"
    var type = _str(j['type']).trim();
    if (type.isEmpty) type = _str(j['event']).trim();

    // normalize: treat any booking.* as booking.changed (so UI refresh always happens)
    if (type.startsWith('booking.') && type != 'booking.changed') {
      type = 'booking.changed';
    }

    // Support camelCase + snake_case
    final locationId = _str(j['locationId']).trim().isNotEmpty
        ? _str(j['locationId']).trim()
        : _str(j['location_id']).trim();

    final bayId = j.containsKey('bayId')
        ? _int(j['bayId'], fallback: 1)
        : _int(j['bay_id'], fallback: 1);

    // Support "at" or "ts"
    final at = j.containsKey('at') ? _dt(j['at']) : _dt(j['ts']);

    return BookingRealtimeEvent(
      type: type,
      locationId: locationId,
      bayId: bayId,
      at: at,
    );
  }
}

class RealtimeClient {
  final Uri wsUri;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  final _ctrl = StreamController<BookingRealtimeEvent>.broadcast();

  Timer? _reconnectTimer;
  bool _closed = false;

  Stream<BookingRealtimeEvent> get events => _ctrl.stream;

  RealtimeClient({required this.wsUri});

  factory RealtimeClient.fromBaseUrl(String baseUrl) {
    final b = baseUrl.trim();
    final httpUri = Uri.parse(b);

    final isHttps = httpUri.scheme == 'https';
    final wsScheme = isHttps ? 'wss' : 'ws';

    final wsUri = Uri(
      scheme: wsScheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : (isHttps ? 443 : 80),
      path: '/ws',
    );

    return RealtimeClient(wsUri: wsUri);
  }

  void connect() {
    if (_closed) return;
    _reconnectTimer?.cancel();

    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print('WS CONNECT -> $wsUri');
      }

      _ch = WebSocketChannel.connect(wsUri);

      _sub = _ch!.stream.listen(
        (msg) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('WS IN <- $msg');
          }

          try {
            final raw = msg is String ? msg : msg.toString();
            final decoded = jsonDecode(raw);

            if (decoded is Map) {
              final map = Map<String, dynamic>.from(decoded);
              final ev = BookingRealtimeEvent.fromJson(map);
              if (ev.type.trim().isNotEmpty) {
                _ctrl.add(ev);
              }
            }
          } catch (_) {
            // ignore malformed
          }
        },
        onError: (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('WS ERROR: $e');
          }
          _scheduleReconnect();
        },
        onDone: () {
          if (kDebugMode) {
            // ignore: avoid_print
            print('WS DONE (closed)');
          }
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('WS CONNECT FAILED: $e');
      }
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;

    _sub?.cancel();
    _sub = null;
    _ch = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), connect);
  }

  Future<void> close() async {
    _closed = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _sub?.cancel();
    _sub = null;

    await _ch?.sink.close();
    _ch = null;

    await _ctrl.close();
  }
}
