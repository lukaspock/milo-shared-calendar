import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';

class ChatView extends ConsumerStatefulWidget {
  final String calendarId;
  final String currentUserId;
  final Color calDeepColor;

  const ChatView({
    super.key,
    required this.calendarId,
    required this.currentUserId,
    required this.calDeepColor,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(chatProvider(widget.calendarId).notifier);
    notifier.setVisible(true);
    final state = ref.read(chatProvider(widget.calendarId));
    if (state.messages.isEmpty) {
      notifier.loadMessages();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    ref.read(chatProvider(widget.calendarId).notifier).setVisible(false);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatProvider(widget.calendarId).notifier).loadMore();
    }
  }

  Future<void> _send() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textController.clear();
    try {
      await ref.read(chatProvider(widget.calendarId).notifier).sendMessage(content);
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.calendarId));
    final messages = chatState.messages;

    return Column(
      children: [
        Expanded(
          child: chatState.isLoading && messages.isEmpty
              ? Center(
                  child: CircularProgressIndicator(
                    color: context.appColors.ink,
                  ),
                )
              : messages.isEmpty
                  ? Center(
                      child: Text(
                        'Noch keine Nachrichten.\nSchreibe die erste!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.appColors.inkMuted,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: messages.length +
                          (chatState.isLoading && messages.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final msg = messages[index];
                        final prevMsg =
                            index + 1 < messages.length ? messages[index + 1] : null;
                        final isOwn = msg.userId == widget.currentUserId;
                        final isFirstInGroup =
                            prevMsg == null || prevMsg.userId != msg.userId;
                        return _MessageTile(
                          message: msg,
                          isOwn: isOwn,
                          showSender: isFirstInGroup && !isOwn,
                          calDeepColor: widget.calDeepColor,
                          onDelete: isOwn && !msg.isDeleted
                              ? () => _confirmDelete(context, msg)
                              : null,
                        );
                      },
                    ),
        ),
        _InputBar(
          controller: _textController,
          sending: _sending,
          onSend: _send,
          accentColor: widget.calDeepColor,
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              'Nachricht löschen',
              style: GoogleFonts.plusJakartaSans(color: Colors.red),
            ),
            onTap: () {
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: context.appColors.surface,
                  title: Text(
                    'Löschen?',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: context.appColors.ink,
                    ),
                  ),
                  content: Text(
                    'Diese Nachricht wird für alle gelöscht.',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.appColors.inkSoft,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Abbrechen',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.appColors.inkMuted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ref
                            .read(chatProvider(widget.calendarId).notifier)
                            .deleteMessage(msg.id);
                      },
                      child: Text(
                        'Löschen',
                        style: GoogleFonts.plusJakartaSans(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final bool showSender;
  final Color calDeepColor;
  final VoidCallback? onDelete;

  const _MessageTile({
    required this.message,
    required this.isOwn,
    required this.showSender,
    required this.calDeepColor,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Padding(
        padding: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isOwn ? 64 : 48,
          right: isOwn ? 0 : 64,
        ),
        child: Align(
          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            'Nachricht gelöscht',
            style: GoogleFonts.plusJakartaSans(
              color: context.appColors.inkMuted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final bubbleColor = isOwn
        ? calDeepColor.withOpacity(0.15)
        : context.appColors.surfaceSoft;
    final borderColor = isOwn ? calDeepColor : context.appColors.line;
    final textColor = context.appColors.ink;

    Widget bubble = GestureDetector(
      onLongPress: onDelete,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isOwn ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          message.content,
          style: GoogleFonts.plusJakartaSans(
            color: textColor,
            fontSize: 14,
          ),
        ),
      ),
    );

    if (isOwn) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: bubble,
        ),
      );
    }

    final avatarColor = _hexToColor(message.senderColor) ?? const Color(0xFF6C63FF);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SenderAvatar(
                avatarUrl: message.senderAvatarUrl,
                name: message.senderName,
                color: avatarColor,
              ),
            )
          else
            const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      message.senderName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.inkMuted,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

class _SenderAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final Color color;

  const _SenderAvatar({
    required this.avatarUrl,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: color,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final Color accentColor;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(
          top: BorderSide(color: context.appColors.line, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              style: GoogleFonts.plusJakartaSans(
                color: context.appColors.ink,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Nachricht…',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: context.appColors.inkMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
