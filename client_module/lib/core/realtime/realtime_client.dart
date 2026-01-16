import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class BookingRealtimeEvent {
  final String type; // 'booking.changed'
  final int bayId;
  final DateTime at;

  BookingRealtimeEvent({
    required this.type,
    required this.bayId,
    required this.at,
  });

  factory BookingRealtimeEvent.fromJson(Map<String, dynamic> j) {
    return BookingRealtimeEvent(
      type: (j['type'] ?? '').toString(),
      bayId: (j['bayId'] as num?)?.toInt() ?? 1,
      at:
          DateTime.tryParse((j['at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
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

  void connect() {
    if (_closed) return;
    _reconnectTimer?.cancel();

    try {
      _ch = WebSocketChannel.connect(wsUri);

      _sub = _ch!.stream.listen(
        (msg) {
          try {
            final m = jsonDecode(msg as String);
            if (m is Map<String, dynamic>) {
              final ev = BookingRealtimeEvent.fromJson(m);
              if (ev.type.isNotEmpty) {
                _ctrl.add(ev);
              }
            }
          } catch (_) {
            // ignore malformed
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
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
