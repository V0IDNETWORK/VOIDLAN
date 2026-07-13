import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/device_model.dart';
import '../../../data/models/transfer_task_model.dart';
import '../../providers/network_providers.dart';
import '../../providers/pairing_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/transfer_providers.dart';
import '../../shared/glass_app_bar.dart';

/// Full detail view for a single device: identity, live ping, shared
/// services, and the send/receive transfer UI (including desktop
/// drag & drop).
class DeviceDetailsScreen extends ConsumerStatefulWidget {
  const DeviceDetailsScreen({super.key, required this.ipAddress});

  final String ipAddress;

  @override
  ConsumerState<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends ConsumerState<DeviceDetailsScreen> {
  bool _dragging = false;

  Future<void> _sendFiles(DeviceModel device, List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      unawaited(ref.read(fileTransferServiceProvider).sendFile(
            peerIp: device.ipAddress,
            file: file,
            peerName: device.displayName,
          ));
    }
  }

  Future<void> _pickAndSend(DeviceModel device) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    await _sendFiles(device, paths);
  }

  Future<void> _requestPairing(DeviceModel device) async {
    final identity = await ref.read(deviceIdentityProvider.future);
    final peerId = device.deviceId;
    if (peerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This device is not running VOID LAN yet.'),
        ));
      }
      return;
    }
    final accepted = await ref.read(pairingServiceProvider)?.requestPairing(
              peerIp: device.ipAddress,
              peerId: peerId,
              localName: identity.name,
            ) ??
        false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accepted ? 'Paired with ${device.displayName}' : 'Pairing declined or timed out'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceListProvider);
    final device = devices.firstWhere(
      (d) => d.ipAddress == widget.ipAddress,
      orElse: () => DeviceModel(
        ipAddress: widget.ipAddress,
        status: DeviceStatus.offline,
      ),
    );
    final transfers = ref
        .watch(transferListProvider)
        .where((t) => t.peerIp == widget.ipAddress)
        .toList();
    final pairedPeers = ref.watch(pairedPeersProvider);
    final isPaired = device.deviceId != null && pairedPeers.contains(device.deviceId);

    return Scaffold(
      appBar: GlassAppBar(title: Text(device.displayName)),
      body: DropTarget(
        onDragDone: (details) => _sendFiles(
            device, details.files.map((f) => f.path).toList()),
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        child: Container(
          color: _dragging
              ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
              : null,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'IP address', value: device.ipAddress),
                      _InfoRow(label: 'Hostname', value: device.hostname ?? '—'),
                      _InfoRow(label: 'MAC address', value: device.macAddress ?? '—'),
                      _InfoRow(
                          label: 'Operating system', value: device.operatingSystem ?? '—'),
                      _InfoRow(
                          label: 'Ping',
                          value: device.pingMs != null ? '${device.pingMs} ms' : '—'),
                      _InfoRow(
                          label: 'Status',
                          value: device.status.name[0].toUpperCase() +
                              device.status.name.substring(1)),
                      _InfoRow(
                          label: 'Shared services',
                          value: device.isVoidLanPeer
                              ? 'VOID LAN (chat, transfer)'
                              : 'Generic host'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _pickAndSend(device),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Send files'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isPaired ? null : () => _requestPairing(device),
                      icon: Icon(isPaired ? Icons.verified_user : Icons.lock_outline),
                      label: Text(isPaired ? 'Paired' : 'Pair device'),
                    ),
                  ),
                ],
              ),
              if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) ...[
                const SizedBox(height: 8),
                Text('or drag & drop files anywhere on this page',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (transfers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Transfers', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final task in transfers) _TransferRow(task: task),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({required this.task});

  final TransferTaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = task.state == TransferState.transferring ||
        task.state == TransferState.connecting;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(task.direction == TransferDirection.send
                    ? Icons.upload
                    : Icons.download),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(task.fileName, overflow: TextOverflow.ellipsis)),
                if (isActive)
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        ref.read(transferListProvider.notifier).cancel(task.id),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 4),
            Text(
              '${task.state.name} · ${(task.progress * 100).toStringAsFixed(0)}%'
              '${task.speedBytesPerSec > 0 ? ' · ${(task.speedBytesPerSec / 1024 / 1024).toStringAsFixed(1)} MB/s' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
