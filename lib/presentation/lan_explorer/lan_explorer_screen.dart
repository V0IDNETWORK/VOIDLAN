import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../providers/connectivity_provider.dart';
import '../providers/network_providers.dart';
import '../providers/pairing_providers.dart';
import '../providers/service_providers.dart';
import '../providers/transfer_providers.dart';
import '../shared/glass_app_bar.dart';
import 'widgets/device_tile.dart';
import 'widgets/incoming_transfer_dialog.dart';
import 'widgets/pairing_request_dialog.dart';
import 'widgets/radar_sweep.dart';

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
      return const Scaffold(body: _BootSplash());
    }
    if (bootState.hasValue || bootState.hasError) {
      if (!_requestedInitialScan) {
        _requestedInitialScan = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _runScan());
      }
    }

    return Scaffold(
      appBar: GlassAppBar(
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
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Transfer history',
            onPressed: () => context.push(AppRoutes.transfers),
            icon: const Icon(Icons.swap_vert_circle_outlined),
          ),
          IconButton(
            tooltip: 'Network status',
            onPressed: () => context.push(AppRoutes.networkStatus),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (bootState.hasError)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'Local server could not start — this device won\'t be discoverable, but scanning still works.',
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lan_explorer_fab',
        onPressed: () => _showConnectByIpDialog(context, ref),
        icon: const Icon(Icons.add_link),
        label: const Text('Connect by IP'),
      ),
    );
  }

  Future<void> _showConnectByIpDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connect by IP'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '192.168.1.42',
            helperText: 'For networks where automatic discovery is blocked '
                '(some mobile hotspots) — enter the other device\'s IP directly.',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    final ip = result?.trim();
    if (ip == null || ip.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Connecting to $ip…')));
    final success = await ref.read(deviceListProvider.notifier).connectByIp(ip);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(success ? 'Connected to $ip' : 'Could not reach $ip'),
    ));
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF7B2FFF), Color(0xFF00E5FF)],
            ).createShader(bounds),
            child: const Icon(Icons.hub_outlined, size: 64, color: Colors.white),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                begin: 0.92,
                end: 1.06,
                duration: 1100.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 20),
          Text('Starting VOID LAN…', style: Theme.of(context).textTheme.titleMedium),
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
          Stack(
            alignment: Alignment.center,
            children: [
              RadarSweep(active: isScanning),
              Icon(Icons.wifi_tethering, size: 40,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
            ],
          ),
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
