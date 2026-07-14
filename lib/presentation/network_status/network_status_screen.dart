import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/network_status_provider.dart';
import '../shared/glass_app_bar.dart';

class NetworkStatusScreen extends ConsumerWidget {
  const NetworkStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(networkStatusProvider);

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Network Status'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(networkStatusProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not read network info: $error')),
        data: (snapshot) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _QualityCard(snapshot: snapshot),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _InfoTile(icon: Icons.wifi, label: 'Connection type', value: snapshot.connectionType),
                  _InfoTile(
                    icon: Icons.router_outlined,
                    label: 'Network name (SSID)',
                    value: snapshot.ssid ?? 'Unavailable on this platform/permission state',
                  ),
                  _InfoTile(
                      icon: Icons.dns_outlined,
                      label: 'Local IP address',
                      value: snapshot.localIp ?? 'Unknown'),
                  _InfoTile(
                      icon: Icons.alt_route,
                      label: 'Gateway IP',
                      value: snapshot.gatewayIp ?? 'Unavailable on this platform'),
                  _InfoTile(
                      icon: Icons.grid_view_outlined, label: 'Subnet mask', value: snapshot.subnetMask),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Signal strength (RSSI) and raw link speed require native platform '
                  'channels this build does not include, so they are intentionally left '
                  'out rather than shown as invented numbers. "Connection quality" above '
                  'is derived instead from real round-trip ping times to devices found '
                  'during your last LAN scan.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.snapshot});

  final NetworkStatusSnapshot snapshot;

  (String, Color, IconData) _presentation(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (snapshot.quality) {
      case ConnectionQuality.good:
        return ('Good', Colors.greenAccent.shade400, Icons.signal_cellular_alt);
      case ConnectionQuality.fair:
        return ('Fair', Colors.amberAccent.shade400, Icons.signal_cellular_alt_2_bar_outlined);
      case ConnectionQuality.poor:
        return ('Poor', scheme.error, Icons.signal_cellular_alt_1_bar_outlined);
      case ConnectionQuality.unknown:
        return ('Unknown — scan for devices first', scheme.onSurface.withOpacity(0.5),
            Icons.signal_cellular_connected_no_internet_0_bar_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _presentation(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 26, backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connection quality', style: Theme.of(context).textTheme.bodySmall),
                Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
                if (snapshot.averagePingMs != null)
                  Text('Avg. ${snapshot.averagePingMs} ms across discovered devices',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
