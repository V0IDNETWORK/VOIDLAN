import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message_model.dart';
import 'connection_manager.dart';
import 'peer_connection.dart';

/// Chat layer built on top of [ConnectionManager]'s control-port
/// connections. Every message, typing event, and read receipt is a
/// small JSON control frame — file/image/video attachments carry only
/// their metadata here; the actual bytes go through
/// [FileTransferService] on the dedicated transfer port and are linked
/// back to the message by a shared `id`.
class MessengerService {
  MessengerService(this._connections, {required this.localDeviceId, Logger? logger})
      : _logger = logger ?? Logger() {
    _connections.onConnection.listen(_attachListener);
    for (final conn in _connections.activeConnections.values) {
      _attachListener(conn);
    }
  }

  final ConnectionManager _connections;
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
    final loaded = await _loadFromDisk(conversationId);
    _messages[conversationId] = loaded;
    return loaded;
  }

  void ensureConversation({
    required String peerId,
    required String peerName,
    required String peerIp,
  }) {
    final id = conversationIdFor(peerId);
    _conversations.putIfAbsent(
      id,
      () => ConversationModel(
          id: id, peerId: peerId, peerName: peerName, peerIp: peerIp),
    );
    _conversationsController.add(_conversations.values.toList());
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
    _persist(message.conversationId);

    final existing = _conversations[message.conversationId];
    if (existing != null) {
      _conversations[message.conversationId] = existing.copyWith(
        lastMessage: message,
        unreadCount:
            message.isOutgoing ? existing.unreadCount : existing.unreadCount + 1,
      );
      _conversationsController.add(_conversations.values.toList());
    }
  }

  void _updateStatus(ChatMessageModel message, MessageStatus status) {
    final list = _messages[message.conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == message.id);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(status: status);
    _messageController.add(list[idx]);
  }

  void _markSeen(String conversationId, String messageId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(status: MessageStatus.seen);
    _messageController.add(list[idx]);
  }

  void togglePin(String conversationId, String messageId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(isPinned: !list[idx].isPinned);
    _messageController.add(list[idx]);
    _persist(conversationId);
  }

  void deleteMessage(String conversationId, String messageId) {
    final list = _messages[conversationId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(isDeleted: true);
    _messageController.add(list[idx]);
    _persist(conversationId);
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

  Future<Directory> _conversationsDir() async {
    final dir = await getApplicationSupportDirectory();
    final chatsDir = Directory(p.join(dir.path, 'conversations'));
    if (!await chatsDir.exists()) await chatsDir.create(recursive: true);
    return chatsDir;
  }

  Future<void> _persist(String conversationId) async {
    try {
      final dir = await _conversationsDir();
      final file = File(p.join(dir.path, '$conversationId.json'));
      final list = _messages[conversationId] ?? [];
      final payload = list
          .where((m) => !m.isDeleted)
          .map((m) => {...m.toJson(), 'isOutgoing': m.isOutgoing})
          .toList();
      await file.writeAsString(jsonEncode(payload));
    } catch (e) {
      _logger.w('Failed to persist conversation $conversationId: $e');
    }
  }

  Future<List<ChatMessageModel>> _loadFromDisk(String conversationId) async {
    try {
      final dir = await _conversationsDir();
      final file = File(p.join(dir.path, '$conversationId.json'));
      if (!await file.exists()) return [];
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw
          .map((e) => ChatMessageModel.fromJson(
                e as Map<String, dynamic>,
                isOutgoing: e['isOutgoing'] as bool? ?? false,
              ))
          .toList();
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
