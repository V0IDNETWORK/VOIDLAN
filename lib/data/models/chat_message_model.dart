import 'package:flutter/foundation.dart';

enum MessageType { text, image, video, file, voice }

enum MessageStatus { sending, sent, delivered, seen, failed }

/// A single chat message exchanged with a peer over the control TCP
/// connection. Persisted per-conversation in [MessengerService].
@immutable
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isOutgoing,
    required this.type,
    required this.timestamp,
    this.text,
    this.filePath,
    this.fileName,
    this.fileSizeBytes,
    this.status = MessageStatus.sending,
    this.replyToId,
    this.isPinned = false,
    this.isDeleted = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final bool isOutgoing;
  final MessageType type;
  final DateTime timestamp;
  final String? text;
  final String? filePath;
  final String? fileName;
  final int? fileSizeBytes;
  final MessageStatus status;
  final String? replyToId;
  final bool isPinned;
  final bool isDeleted;

  ChatMessageModel copyWith({
    MessageStatus? status,
    bool? isPinned,
    bool? isDeleted,
  }) {
    return ChatMessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      isOutgoing: isOutgoing,
      type: type,
      timestamp: timestamp,
      text: text,
      filePath: filePath,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      status: status ?? this.status,
      replyToId: replyToId,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'text': text,
        'fileName': fileName,
        'fileSizeBytes': fileSizeBytes,
        'replyToId': replyToId,
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json,
      {required bool isOutgoing}) {
    return ChatMessageModel(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      isOutgoing: isOutgoing,
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      text: json['text'] as String?,
      fileName: json['fileName'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      replyToId: json['replyToId'] as String?,
      status: MessageStatus.delivered,
    );
  }
}

/// A conversation groups messages exchanged with a single peer device.
@immutable
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerIp,
    this.lastMessage,
    this.unreadCount = 0,
    this.isTyping = false,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String peerIp;
  final ChatMessageModel? lastMessage;
  final int unreadCount;
  final bool isTyping;

  ConversationModel copyWith({
    ChatMessageModel? lastMessage,
    int? unreadCount,
    bool? isTyping,
  }) {
    return ConversationModel(
      id: id,
      peerId: peerId,
      peerName: peerName,
      peerIp: peerIp,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}
