import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/auth_service.dart';

// Change to ws://YOUR_IP:3000/ws for physical device
const _wsUrl = 'ws://localhost:3000/ws';

typedef WsMessageCallback = void Function(Map<String, dynamic> message);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  factory WebSocketService() => _instance;
  WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  final List<WsMessageCallback> _listeners = [];

  void addListener(WsMessageCallback cb) => _listeners.add(cb);
  void removeListener(WsMessageCallback cb) => _listeners.remove(cb);

  Future<void> connect(List<String> calendarIds) async {
    _shouldReconnect = true;
    await _connect(calendarIds);
  }

  Future<void> _connect(List<String> calendarIds) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        (raw) {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          // After auth_ok, subscribe to calendars
          if (type == 'auth_ok') {
            _send({'type': 'subscribe', 'calendarIds': calendarIds});
          }

          for (final cb in List.of(_listeners)) {
            cb(msg);
          }
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );

      // Authenticate
      final token = await AuthService().getStoredToken();
      if (token != null) {
        _send({'type': 'auth', 'token': token});
      }
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _channel = null;
    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        // We don't store calendarIds here — caller must re-call connect()
      });
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
