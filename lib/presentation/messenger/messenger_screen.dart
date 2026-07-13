import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/device_model.dart';
import '../providers/messenger_providers.dart';
import '../providers/network_providers.dart';
import '../providers/service_providers.dart';
import '../shared/glass_app_bar.dart';
import 'widgets/conversation_tile.dart';

/// Tab 3 — offline local messenger. Lists existing conversations and
/// lets the user start a new one with any VOID LAN peer currently
/// visible in the LAN Explorer scan.
class MessengerScreen extends ConsumerWidget {
  const MessengerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);
    final peers =
        ref.watch(deviceListProvider).where((d) => d.isVoidLanPeer).toList();

    return Scaffold(
      appBar: GlassAppBar(title: const Text('Messenger')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNearbyPeers(context, ref, peers),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New chat'),
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Messenger unavailable: $e')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 56, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('No conversations yet'),
                  const SizedBox(height: 4),
                  Text('Tap "New chat" to message a nearby device',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ConversationTile(
                conversation: conversation,
                onTap: () => context.go(
                  '${AppRoutes.messenger}/${AppRoutes.chat}/${conversation.id}'
                  '?peerName=${Uri.encodeComponent(conversation.peerName)}'
                  '&peerId=${Uri.encodeComponent(conversation.peerId)}'
                  '&peerIp=${Uri.encodeComponent(conversation.peerIp)}',
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showNearbyPeers(BuildContext context, WidgetRef ref, List<DeviceModel> peers) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: peers.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No VOID LAN peers found yet. Scan in LAN Explorer first.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final peer in peers)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(peer.displayName),
                      subtitle: Text(peer.ipAddress),
                      onTap: () {
                        final messenger = ref.read(messengerServiceProvider);
                        messenger?.ensureConversation(
                          peerId: peer.deviceId ?? peer.ipAddress,
                          peerName: peer.displayName,
                          peerIp: peer.ipAddress,
                        );
                        Navigator.pop(context);
                        final conversationId =
                            messenger?.conversationIdFor(peer.deviceId ?? peer.ipAddress) ?? '';
                        context.go(
                          '${AppRoutes.messenger}/${AppRoutes.chat}/$conversationId'
                          '?peerName=${Uri.encodeComponent(peer.displayName)}'
                          '&peerId=${Uri.encodeComponent(peer.deviceId ?? peer.ipAddress)}'
                          '&peerIp=${Uri.encodeComponent(peer.ipAddress)}',
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
