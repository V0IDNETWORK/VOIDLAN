import 'dart:async';

import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message_model.dart';
import 'connection_manager.dart';
import 'database_service.dart';
import 'peer_connection.dart';

/// Chat layer built on top of [ConnectionManager]'s control-port
/// connections. Every message, typing event, and read receipt is a
/// small JSON control frame — file/image/video attachments carry only
/// their metadata here; the actual bytes go through
/// [FileTransferService] on the dedicated transfer port and are linked
/// back to the message by a shared `id`.
///
/// Persistence lives in SQLite via [DatabaseService]: each call below
/// writes or reads exactly the row(s) it touches, rather than the
/// previous JSON-file design's read-modify-write-whole-file per
/// message. Conversations are now persisted too, so they (not just
/// their messages) survive an app restart.
class MessengerService {
  MessengerService(
    this._connections,
    this._db, {
    required this.localDeviceId,
    Logger? logger,
  }) : _logger = logger ?? Logger() {
    _connections.onConnection.listen(_attachListener);
    for (final conn in _connections.activeConnections.values) {
      _attachListener(conn);
    }
    _loadConversations();
  }

  final ConnectionManager _connections;
  final DatabaseService _db;
  final String localDeviceId;
  final Logger _logger;
  final _uuid = const Uuid();

  final Map<String, ConversationModel> _conversations = {};
  final Map<String, List<ChatMessageModel>> _messages = {};

  final _conversationsController =
      StreamController<List<ConversationModel>>.broadcast();
  final _messageController = StreamController<ChatMessageModel>.broadcast();
  final _typingController = StreamController<String>.broadcast();

  Stream<List<ConversationModel>> get conversations =>
      _conversationsController.stream;

  /// Emits every newly received or sent message (append-only feed); the
  /// UI groups these by [ChatMessageModel.conversationId].
  Stream<ChatMessageModel> get messageStream => _messageController.stream;

  /// Emits a peer id whenever that peer starts typing.
  Stream<String> get typingStream => _typingController.stream;

  Future<void> _loadConversations() async {
    try {
      final db = await _db.database;
      final rows = await db.query('conversations');
      for (final row in rows) {
        final conversation = ConversationModel(
          id: row['id'] as String,
          peerId: row['peer_id'] as String,
          peerName: row['peer_name'] as String,
          peerIp: row['peer_ip'] as String,
          unreadCount: row['unread_count'] as int,
        );
        _conversations[conversation.id] = conversation;
      }
      if (_conversations.isNotEmpty) {
        _conversationsController.add(_conversations.values.toList());
      }
    } catch (e) {
      _logger.w('Failed to load conversations: $e');
    }
  }

  void _attachListener(PeerConnection conn) {
    conn.messages.listen((json) {
      switch (json['type']) {
        case 'chat':
          _handleIncomingChat(json, conn.remoteIp);
          break;
        case 'typing':
          _typingController.add(json['senderId'] as String);
          break;
        case 'seen':
          _markSeen(json['conversationId'] as String, json['messageId'] as String);
          break;
      }
    });
  }

  String conversationIdFor(String peerId) {
    final ids = [localDeviceId, peerId]..sort();
    return ids.join('_');
  }

  Future<List<ChatMessageModel>> historyFor(String conversationId) async {
    if (_messages.containsKey(conversationId)) return _messages[conversationId]!;
    final loaded = await _loadMessagesFromDb(conversationId);
    _messages[conversationId] = loaded;
    return loaded;
  }

  void ensureConversation({
    required String peerId,
    required String peerName,
    required String peerIp,
  }) {
    final id = conversationIdFor(peerId);
    if (_conversations.containsKey(id)) return;
    final conversation =
        ConversationModel(id: id, peerId: peerId, peerName: peerName, peerIp: peerIp);
    _conversations[id] = conversation;
    _conversationsController.add(_conversations.values.toList());
    _persistConversation(conversation);
  }

  Future<ChatMessageModel> sendText({
    required String peerId,
    required String peerIp,
    required String text,
    String? replyToId,
  }) async {
    final conversationId = conversationIdFor(peerId);
    final message = ChatMessageModel(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: localDeviceId,
      isOutgoing: true,
      type: MessageType.text,
      timestamp: DateTime.now(),
      text: text,
      replyToId: replyToId,
      status: MessageStatus.sending,
    );

    _appendLocal(message);

    final conn = await _connections.connectTo(peerIp);
    if (conn != null) {
      conn.send({'type': 'chat', ...message.toJson()});
      _updateStatus(message, MessageStatus.sent);
    } else {
      _updateStatus(message, MessageStatus.failed);
    }
    return message;
  }

  Future<ChatMessageModel> sendVoice({
    required String peerId,
    required String peerIp,
    required String fileName,
    required int fileSizeBytes,
    String? localFilePath,
  }) async {
    final conversationId = conversationIdFor(peerId);
    final message = ChatMessageModel(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: localDeviceId,
      isOutgoing: true,
      type: MessageType.voice,
      timestamp: DateTime.now(),
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      filePath: localFilePath,
      status: MessageStatus.sending,
    );

    _appendLocal(message);

    final conn = await _connections.connectTo(peerIp);
    if (conn != null) {
      conn.send({'type': 'chat', ...message.toJson()});
      _updateStatus(message, MessageStatus.sent);
    } else {
      _updateStatus(message, MessageStatus.failed);
    }
    return message;
  }

  void sendTyping(String peerIp) {
    final conn = _connections.connectionFor(peerIp);
    conn?.send({'type': 'typing', 'senderId': localDeviceId});
  }

  void markSeen(String conversationId, String messageId, String peerIp) {
    final conn = _connections.connectionFor(peerIp);
    conn?.send({
      'type': 'seen',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void _handleIncomingChat(Map<String, dynamic> json, String senderIp) {
    final message = ChatMessageModel.fromJson(json, isOutgoing: false);
    ensureConversation(
      peerId: message.senderId,
      peerName: message.senderId,
      peerIp: senderIp,
    );
    _appendLocal(message);
  }

  void _appendLocal(ChatMessageModel message) {
    final list = _messages.putIfAbsent(message.conversationId, () => []);
    list.add(message);
    _messageController.add(message);
    _persistMessage(message);

    final existing = _conversations[message.conversationId];
    if (existing != null) {
      final updated = existing.copyWith(
        lastMessage: message,
        unreadCount:
            message.isOutgoing ? existing.unreadCount : existing.unreadCount + 1,
      );
      _conversations[message.conversationId] = updated;
      _conversationsController.add(_conversations.values.toList());
      _persistConversation(updated);
    }
  }

  void _updateStatus(ChatMessageModel message, MessageStatus status) {
    final list = _messages[message.conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == message.id);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(status: status);
    _messageController.add(list[idx]);
    _persistMessage(list[idx]);
  }

  void _markSeen(String conversationId, String messageId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(status: MessageStatus.seen);
    _messageController.add(list[idx]);
    _persistMessage(list[idx]);
  }

  void togglePin(String conversationId, String messageId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(isPinned: !list[idx].isPinned);
    _messageController.add(list[idx]);
    _persistMessage(list[idx]);
  }

  void deleteMessage(String conversationId, String messageId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(isDeleted: true);
    _messageController.add(list[idx]);
    _persistMessage(list[idx]);
  }

  Future<ChatMessageModel> forwardMessage({
    required ChatMessageModel original,
    required String toPeerId,
    required String toPeerIp,
  }) {
    return sendText(
      peerId: toPeerId,
      peerIp: toPeerIp,
      text: original.text ?? '[${original.type.name}] ${original.fileName ?? ''}',
    );
  }

  List<ChatMessageModel> search(String conversationId, String query) {
    final list = _messages[conversationId] ?? [];
    final lower = query.toLowerCase();
    return list
        .where((m) => (m.text ?? '').toLowerCase().contains(lower))
        .toList();
  }

  Future<void> _persistMessage(ChatMessageModel message) async {
    try {
      final db = await _db.database;
      await db.insert('messages', {
        'id': message.id,
        'conversation_id': message.conversationId,
        'sender_id': message.senderId,
        'is_outgoing': message.isOutgoing ? 1 : 0,
        'type': message.type.name,
        'timestamp': message.timestamp.toIso8601String(),
        'text': message.text,
        'file_path': message.filePath,
        'file_name': message.fileName,
        'file_size_bytes': message.fileSizeBytes,
        'status': message.status.name,
        'reply_to_id': message.replyToId,
        'is_pinned': message.isPinned ? 1 : 0,
        'is_deleted': message.isDeleted ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      _logger.w('Failed to persist message ${message.id}: $e');
    }
  }

  Future<void> _persistConversation(ConversationModel conversation) async {
    try {
      final db = await _db.database;
      await db.insert('conversations', {
        'id': conversation.id,
        'peer_id': conversation.peerId,
        'peer_name': conversation.peerName,
        'peer_ip': conversation.peerIp,
        'unread_count': conversation.unreadCount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      _logger.w('Failed to persist conversation ${conversation.id}: $e');
    }
  }

  Future<List<ChatMessageModel>> _loadMessagesFromDb(String conversationId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'messages',
        where: 'conversation_id = ? AND is_deleted = 0',
        whereArgs: [conversationId],
        orderBy: 'timestamp ASC',
      );
      return rows.map((row) {
        return ChatMessageModel(
          id: row['id'] as String,
          conversationId: row['conversation_id'] as String,
          senderId: row['sender_id'] as String,
          isOutgoing: (row['is_outgoing'] as int) == 1,
          type: MessageType.values.firstWhere((t) => t.name == row['type']),
          timestamp: DateTime.parse(row['timestamp'] as String),
          text: row['text'] as String?,
          filePath: row['file_path'] as String?,
          fileName: row['file_name'] as String?,
          fileSizeBytes: row['file_size_bytes'] as int?,
          status: MessageStatus.values.firstWhere((s) => s.name == row['status'],
              orElse: () => MessageStatus.delivered),
          replyToId: row['reply_to_id'] as String?,
          isPinned: (row['is_pinned'] as int) == 1,
          isDeleted: (row['is_deleted'] as int) == 1,
        );
      }).toList();
    } catch (e) {
      _logger.w('Failed to load conversation $conversationId: $e');
      return [];
    }
  }

  void dispose() {
    _conversationsController.close();
    _messageController.close();
    _typingController.close();
  }
}
