import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../providers/connectivity_provider.dart';
import '../providers/network_providers.dart';
import '../providers/pairing_providers.dart';
import '../providers/service_providers.dart';
import '../providers/transfer_providers.dart';
import 'widgets/device_tile.dart';
import 'widgets/incoming_transfer_dialog.dart';
import 'widgets/pairing_request_dialog.dart';

/// Tab 1 — the app's primary screen. Kicks off the local server, runs
/// LAN scans, and lists every discovered device with live status.
class LanExplorerScreen extends ConsumerStatefulWidget {
  const LanExplorerScreen({super.key});

  @override
  ConsumerState<LanExplorerScreen> createState() => _LanExplorerScreenState();
}

class _LanExplorerScreenState extends ConsumerState<LanExplorerScreen> {
  final _searchController = TextEditingController();
  bool _requestedInitialScan = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    ref.read(isScanningProvider.notifier).state = true;
    try {
      await ref.read(deviceListProvider.notifier).scan();
    } finally {
      if (mounted) ref.read(isScanningProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootState = ref.watch(serverBootProvider);
    final devices = ref.watch(visibleDevicesProvider);
    final isScanning = ref.watch(isScanningProvider);
    final sortMode = ref.watch(deviceSortModeProvider);

    ref.listen(incomingTransferProvider, (previous, next) {
      if (next.isNotEmpty && (previous?.length ?? 0) < next.length) {
        showDialog(
          context: context,
          builder: (_) => IncomingTransferDialog(request: next.last),
        );
      }
    });

    ref.listen(incomingPairingRequestProvider, (previous, next) {
      next.whenData((request) {
        showDialog(
          context: context,
          builder: (_) => PairingRequestDialog(request: request),
        );
      });
    });

    if (bootState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (bootState.hasError && !_requestedInitialScan) {
      // Server failed to bind (e.g. port already in use); scanning still
      // works, it just means this device won't be discoverable by others.
    }
    if (bootState.hasValue && !_requestedInitialScan) {
      _requestedInitialScan = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runScan());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Explorer'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isScanning ? null : _runScan,
            icon: isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<DeviceSortMode>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: sortMode,
            onSelected: (mode) =>
                ref.read(deviceSortModeProvider.notifier).state = mode,
            itemBuilder: (context) => const [
              PopupMenuItem(value: DeviceSortMode.name, child: Text('Name')),
              PopupMenuItem(value: DeviceSortMode.ip, child: Text('IP address')),
              PopupMenuItem(value: DeviceSortMode.ping, child: Text('Ping')),
              PopupMenuItem(value: DeviceSortMode.status, child: Text('Status')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Consumer(
            builder: (context, ref, _) {
              final hasLan = ref.watch(hasLanConnectionProvider).valueOrNull ?? true;
              if (hasLan) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'No Wi-Fi or Ethernet link detected — connect to a local network to scan.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(deviceSearchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search devices…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: devices.isEmpty
                ? _EmptyState(isScanning: isScanning, onScan: _runScan)
                : RefreshIndicator(
                    onRefresh: _runScan,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return DeviceTile(
                          device: device,
                          onTap: () => context.go(
                              '${AppRoutes.explorer}${AppRoutes.deviceDetails}/${device.ipAddress}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isScanning, required this.onScan});

  final bool isScanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering, size: 56,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(isScanning ? 'Scanning your network…' : 'No devices found yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!isScanning)
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan network'),
            ),
        ],
      ),
    );
  }
}
