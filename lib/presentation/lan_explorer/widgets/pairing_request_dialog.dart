import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/pairing_service.dart';
import '../../providers/service_providers.dart';

/// Security requirement: pairing always shows this confirmation dialog,
/// with a short verification code the user can compare against the
/// peer's screen, before any secret is stored and the device is
/// trusted.
class PairingRequestDialog extends ConsumerWidget {
  const PairingRequestDialog({super.key, required this.request});

  final PairingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      icon: const Icon(Icons.lock_outline, size: 32),
      title: const Text('Pairing request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${request.peerName} (${request.peerIp}) wants to pair with this device.'),
          const SizedBox(height: 12),
          const Text('Verification code:'),
          const SizedBox(height: 4),
          Text(
            request.code,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
          const SizedBox(height: 8),
          Text('Confirm this matches the code shown on the other device.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(pairingServiceProvider)?.reject(request.peerId);
            Navigator.of(context).pop();
          },
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(pairingServiceProvider)?.accept(request.peerId);
            Navigator.of(context).pop();
          },
          child: const Text('Confirm pairing'),
        ),
      ],
    );
  }
}
