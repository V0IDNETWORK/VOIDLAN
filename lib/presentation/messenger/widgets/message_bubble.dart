import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../data/models/chat_message_model.dart';
import 'voice_message_content.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onForward,
    this.onDelete,
    this.onTogglePin,
  });

  final ChatMessageModel message;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;

  IconData get _statusIcon {
    switch (message.status) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.seen:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = message.isOutgoing;
    final bubbleColor =
        isOut ? theme.colorScheme.primary.withOpacity(0.9) : theme.cardColor;
    final textColor = isOut ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Align(
        alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isOut ? 16 : 4),
              bottomRight: Radius.circular(isOut ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.push_pin, size: 12, color: textColor.withOpacity(0.7)),
                ),
              if (message.isDeleted)
                Text('Message deleted',
                    style: TextStyle(color: textColor, fontStyle: FontStyle.italic))
              else if (message.type == MessageType.voice)
                VoiceMessageContent(message: message, textColor: textColor)
              else
                Text(message.text ?? '', style: TextStyle(color: textColor)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat.Hm().format(message.timestamp),
                      style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
                  if (isOut) ...[
                    const SizedBox(width: 4),
                    Icon(_statusIcon, size: 12, color: textColor.withOpacity(0.7)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideX(begin: isOut ? 0.08 : -0.08, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                onForward?.call();
              },
            ),
            ListTile(
              leading: Icon(message.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(message.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                onTogglePin?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
