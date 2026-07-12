import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_message_model.dart';
import 'service_providers.dart';

final conversationListProvider = StreamProvider<List<ConversationModel>>((ref) {
  final messenger = ref.watch(messengerServiceProvider);
  if (messenger == null) return const Stream.empty();
  return messenger.conversations;
});

/// Per-conversation message list. Seeds from persisted history, then
/// appends every live message that streams in for that conversation.
class ConversationMessagesNotifier extends StateNotifier<List<ChatMessageModel>> {
  ConversationMessagesNotifier(this._ref, this.conversationId) : super([]) {
    _load();
    final messenger = _ref.read(messengerServiceProvider);
    messenger?.messageStream.listen((message) {
      if (message.conversationId != conversationId) return;
      final index = state.indexWhere((m) => m.id == message.id);
      if (index == -1) {
        state = [...state, message];
      } else {
        final updated = [...state];
        updated[index] = message;
        state = updated;
      }
    });
  }

  final Ref _ref;
  final String conversationId;

  Future<void> _load() async {
    final messenger = _ref.read(messengerServiceProvider);
    if (messenger == null) return;
    final history = await messenger.historyFor(conversationId);
    state = history;
  }
}

final conversationMessagesProvider = StateNotifierProvider.family<
    ConversationMessagesNotifier, List<ChatMessageModel>, String>(
  (ref, conversationId) => ConversationMessagesNotifier(ref, conversationId),
);

final typingPeerProvider = StreamProvider<String>((ref) {
  final messenger = ref.watch(messengerServiceProvider);
  if (messenger == null) return const Stream.empty();
  return messenger.typingStream;
});
