import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/auth_service.dart';

const _apiHost = String.fromEnvironment('API_HOST', defaultValue: '127.0.0.1');
const _wsUrl = 'ws://$_apiHost:3000/ws';

typedef WsMessageCallback = void Function(Map<String, dynamic> message);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._();
  factory WebSocketService() => _instance;
  WebSocketService._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  bool _authed = false;
  final List<WsMessageCallback> _listeners = [];

  // Accumulated set of calendar IDs to subscribe to
  final List<String> _calendarIds = [];

  void addListener(WsMessageCallback cb) => _listeners.add(cb);
  void removeListener(WsMessageCallback cb) => _listeners.remove(cb);

  /// Subscribe to a calendar for real-time events.
  /// Connects the WebSocket if not already open; sends a subscribe message
  /// if already authed.
  Future<void> subscribeToCalendar(String calendarId) async {
    if (!_calendarIds.contains(calendarId)) {
      _calendarIds.add(calendarId);
    }
    if (_channel != null && _authed) {
      _send({
        'type': 'subscribe',
        'calendarIds': [calendarId],
      });
    } else if (_channel == null) {
      _shouldReconnect = true;
      await _connect();
    }
    // if channel open but not yet authed, the auth_ok handler will subscribe
  }

  Future<void> _connect() async {
    try {
      _authed = false;
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel!.stream.listen(
        (raw) {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;

          if (type == 'auth_ok') {
            _authed = true;
            // Subscribe to all accumulated calendar IDs
            if (_calendarIds.isNotEmpty) {
              _send({'type': 'subscribe', 'calendarIds': _calendarIds});
            }
          }

          for (final cb in List.of(_listeners)) {
            cb(msg);
          }
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );

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
    _authed = false;
    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
    }
  }

  void _send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void disconnect() {
    _shouldReconnect = false;
    _authed = false;
    _calendarIds.clear();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
