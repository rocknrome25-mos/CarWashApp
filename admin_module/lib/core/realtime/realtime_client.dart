import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class BookingRealtimeEvent {
  final String type; // expected: 'booking.changed'
  final String locationId;
  final int bayId;
  final DateTime at;

  BookingRealtimeEvent({
    required this.type,
    required this.locationId,
    required this.bayId,
    required this.at,
  });

  factory BookingRealtimeEvent.fromJson(Map<String, dynamic> j) {
    return BookingRealtimeEvent(
      type: (j['type'] ?? '').toString(),
      locationId: (j['locationId'] ?? '').toString(),
      bayId: (j['bayId'] as num?)?.toInt() ?? 1,
      at:
          DateTime.tryParse((j['at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

/// Admin realtime client (raw WebSocket).
/// Auto-detects ws endpoint by trying:
///   ws(s)://host/ws
///   ws(s)://host/bookings
///   ws(s)://host/
///
/// Works with server that emits JSON messages like:
/// { "type":"booking.changed","locationId":"...","bayId":1,"at":"..." }
class RealtimeClient {
  final String baseHttpUrl;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;

  final _ctrl = StreamController<BookingRealtimeEvent>.broadcast();

  Timer? _reconnectTimer;
  bool _closed = false;

  int _tryIndex = 0;
  List<Uri> _candidates = const [];

  Stream<BookingRealtimeEvent> get events => _ctrl.stream;

  RealtimeClient({required this.baseHttpUrl});

  void connect() {
    if (_closed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _candidates = _buildCandidates(baseHttpUrl);
    if (_candidates.isEmpty) return;

    _tryIndex = 0;
    _tryConnectNext();
  }

  List<Uri> _buildCandidates(String httpBase) {
    final raw = httpBase.trim();
    if (raw.isEmpty) return const [];

    // normalize: remove trailing slash
    final normalized = raw.endsWith('/')
        ? raw.substring(0, raw.length - 1)
        : raw;

    // http -> ws, https -> wss
    final wsBase = normalized.startsWith('https://')
        ? normalized.replaceFirst('https://', 'wss://')
        : normalized.startsWith('http://')
        ? normalized.replaceFirst('http://', 'ws://')
        : normalized; // if already ws:// or wss://

    Uri u(String p) => Uri.parse('$wsBase$p');

    // Try most likely first
    return [u('/ws'), u('/bookings'), u('')];
  }

  void _tryConnectNext() {
    if (_closed) return;

    if (_tryIndex >= _candidates.length) {
      _scheduleReconnect();
      return;
    }

    final uri = _candidates[_tryIndex];
    _tryIndex++;

    try {
      _ch = WebSocketChannel.connect(uri);

      _sub = _ch!.stream.listen(
        (msg) {
          try {
            final m = jsonDecode(msg as String);
            if (m is Map<String, dynamic>) {
              final ev = BookingRealtimeEvent.fromJson(m);
              if (ev.type.isNotEmpty) _ctrl.add(ev);
            }
          } catch (_) {
            // ignore malformed
          }
        },
        onError: (_) {
          _cleanupSocket();
          // try next candidate immediately
          _tryConnectNext();
        },
        onDone: () {
          _cleanupSocket();
          // if connection drops after being established, reconnect later
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _cleanupSocket();
      _tryConnectNext();
    }
  }

  void _cleanupSocket() {
    _sub?.cancel();
    _sub = null;
    _ch = null;
  }

  void _scheduleReconnect() {
    if (_closed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_closed) return;
      connect();
    });
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
