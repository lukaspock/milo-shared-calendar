import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_notification_service.dart';
import '../services/websocket_service.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final int unreadCount;

  const ChatState({
    required this.messages,
    required this.isLoading,
    required this.hasMore,
    required this.unreadCount,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    int? unreadCount,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String calendarId;
  final Ref ref;

  final _api = ApiService();
  final _ws = WebSocketService();
  bool _isVisible = false;
  bool _disposed = false;

  late final void Function(Map<String, dynamic>) _wsListener;

  ChatNotifier(this.calendarId, this.ref)
      : super(const ChatState(
          messages: [],
          isLoading: false,
          hasMore: true,
          unreadCount: 0,
        )) {
    _wsListener = _handleWsMessage;
    _ws.addListener(_wsListener);
    _ws.subscribeToCalendar(calendarId);
  }

  Future<void> loadMessages() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      final msgs = await _api.getChatMessages(calendarId);
      final lastRead = await _loadLastRead();
      final currentUserId = AuthService().cachedUser?.id;
      final unread = lastRead == null
          ? 0
          : msgs
              .where((m) =>
                  m.userId != currentUserId &&
                  m.createdAt.isAfter(lastRead))
              .length;
      state = state.copyWith(
        messages: msgs,
        isLoading: false,
        hasMore: msgs.length >= 50,
        unreadCount: unread,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final oldest = state.messages.last.createdAt.toUtc().toIso8601String();
      final more = await _api.getChatMessages(calendarId, before: oldest);
      state = state.copyWith(
        messages: [...state.messages, ...more],
        isLoading: false,
        hasMore: more.length >= 50,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> sendMessage(String content) async {
    final msg = await _api.sendChatMessage(calendarId, content);
    // Optimistically prepend if not already added by WS
    if (!state.messages.any((m) => m.id == msg.id)) {
      state = state.copyWith(messages: [msg, ...state.messages]);
    }
  }

  Future<void> deleteMessage(String msgId) async {
    await _api.deleteChatMessage(calendarId, msgId);
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == msgId ? m.copyWith(isDeleted: true, content: '') : m)
          .toList(),
    );
  }

  void setVisible(bool visible) {
    _isVisible = visible;
    if (visible) markAsRead();
  }

  Future<void> ensureLoaded() async {
    if (state.messages.isEmpty && !state.isLoading) {
      await loadMessages();
    }
  }

  Future<void> markAsRead() async {
    state = state.copyWith(unreadCount: 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'chat_last_read_$calendarId',
      DateTime.now().toIso8601String(),
    );
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    if (msg['type'] == 'chat_message' && msg['calendar_id'] == calendarId) {
      final newMsg = ChatMessage.fromJson(msg['message'] as Map<String, dynamic>);
      if (state.messages.any((m) => m.id == newMsg.id)) return;
      state = state.copyWith(messages: [newMsg, ...state.messages]);
      if (!_isVisible) {
        state = state.copyWith(unreadCount: state.unreadCount + 1);
        _showLocalNotificationIfNeeded(newMsg);
      }
    } else if (msg['type'] == 'chat_message_deleted' &&
        msg['calendar_id'] == calendarId) {
      final msgId = msg['message_id'] as String;
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == msgId ? m.copyWith(isDeleted: true, content: '') : m)
            .toList(),
      );
    }
  }

  void _showLocalNotificationIfNeeded(ChatMessage msg) {
    final user = AuthService().cachedUser;
    if (user == null) return;
    if (user.notificationType != NotificationType.push) return;
    if (msg.userId == user.id) return;

    _showLocalNotificationAsync(msg);
  }

  Future<void> _showLocalNotificationAsync(ChatMessage msg) async {
    try {
      final bytes = await _buildNotificationIcon(msg);
      if (_disposed) return;
      LocalNotificationService().showChatNotification(
        calendarId: calendarId,
        title: msg.senderName,
        body: msg.content,
        largeIconBytes: bytes,
      );
    } catch (_) {}
  }

  Future<Uint8List?> _buildNotificationIcon(ChatMessage msg) async {
    if (msg.senderAvatarUrl != null) {
      try {
        final resp = await http.get(Uri.parse(msg.senderAvatarUrl!));
        if (resp.statusCode == 200) return resp.bodyBytes;
      } catch (_) {}
    }
    return _generateInitialBitmap(
      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
      _hexToColor(msg.senderColor) ?? const Color(0xFF6C63FF),
    );
  }

  Future<Uint8List> _generateInitialBitmap(String initial, Color color) async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ))
      ..addText(initial);
    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(
      paragraph,
      Offset(0, (size - paragraph.height) / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<DateTime?> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('chat_last_read_$calendarId');
    if (s == null) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ws.removeListener(_wsListener);
    super.dispose();
  }
}

Color? _hexToColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  } catch (_) {
    return null;
  }
}

final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, calendarId) => ChatNotifier(calendarId, ref),
);
