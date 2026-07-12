import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_message_model.dart';
import '../providers/messenger_providers.dart';
import '../providers/service_providers.dart';
import 'widgets/message_bubble.dart';

const _quickEmoji = ['😀', '😂', '❤️', '👍', '🎉', '🔥', '😢', '🙏'];

/// Tab 3 detail screen — a single conversation thread with a peer.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.peerName,
    required this.peerId,
    required this.peerIp,
  });

  final String conversationId;
  final String peerName;
  final String peerId;
  final String peerIp;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  ChatMessageModel? _replyTarget;
  bool _searching = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(messengerServiceProvider)?.sendText(
          peerId: widget.peerId,
          peerIp: widget.peerIp,
          text: text,
          replyToId: _replyTarget?.id,
        );
    _textController.clear();
    setState(() => _replyTarget = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTyping(String _) {
    ref.read(messengerServiceProvider)?.sendTyping(widget.peerIp);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(conversationMessagesProvider(widget.conversationId));
    final messenger = ref.watch(messengerServiceProvider);

    final visibleMessages = _searching && _searchController.text.isNotEmpty
        ? messenger?.search(widget.conversationId, _searchController.text) ?? []
        : messages;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search messages…',
                  border: InputBorder.none,
                ),
              )
            : Text(widget.peerName),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: visibleMessages.isEmpty
                ? const Center(child: Text('No messages yet — say hello!'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: visibleMessages.length,
                    itemBuilder: (context, index) {
                      final message = visibleMessages[index];
                      return MessageBubble(
                        message: message,
                        onReply: () => setState(() => _replyTarget = message),
                        onTogglePin: () => messenger?.togglePin(
                            widget.conversationId, message.id),
                        onDelete: () => messenger?.deleteMessage(
                            widget.conversationId, message.id),
                        onForward: () => _showForwardSheet(message),
                      );
                    },
                  ),
          ),
          if (_replyTarget != null) _ReplyPreview(
            message: _replyTarget!,
            onCancel: () => setState(() => _replyTarget = null),
          ),
          _Composer(
            controller: _textController,
            onChanged: _onTyping,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _showForwardSheet(ChatMessageModel message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Open the conversation you want to forward to, '
              'then use "New chat" if it is not listed yet.'),
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onCancel});

  final ChatMessageModel message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Replying to: ${message.text}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancel),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onChanged, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final emoji in _quickEmoji)
                    IconButton(
                      onPressed: () => controller.text += emoji,
                      icon: Text(emoji, style: const TextStyle(fontSize: 18)),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Message…'),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(icon: const Icon(Icons.send), onPressed: onSend),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
