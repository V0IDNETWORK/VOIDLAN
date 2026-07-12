import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/file_transfer_service.dart';
import '../../providers/transfer_providers.dart';

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Security requirement: incoming transfers never touch disk without an
/// explicit tap here. Shown from [LanExplorerScreen] whenever
/// [incomingTransferProvider] gains a new entry.
class IncomingTransferDialog extends ConsumerWidget {
  const IncomingTransferDialog({super.key, required this.request});

  final IncomingTransferRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      icon: const Icon(Icons.file_download_outlined, size: 32),
      title: const Text('Incoming file'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('From ${request.senderIp}'),
          const SizedBox(height: 8),
          Text(request.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(_formatBytes(request.totalBytes)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(incomingTransferProvider.notifier).reject(request.transferId);
            Navigator.of(context).pop();
          },
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(incomingTransferProvider.notifier).accept(request.transferId);
            Navigator.of(context).pop();
          },
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
