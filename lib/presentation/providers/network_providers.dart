import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/device_model.dart';
import 'service_providers.dart';

enum DeviceSortMode { name, ip, ping, status }

/// Holds the merged, de-duplicated list of discovered devices and the
/// current scanning/sort/search state consumed by the LAN Explorer UI.
class DeviceListNotifier extends StateNotifier<List<DeviceModel>> {
  DeviceListNotifier(this._ref) : super([]) {
    _ref.listen(deviceIdentityProvider, (_, identity) {
      identity.whenData((value) {
        _ref.read(lanDiscoveryServiceProvider).deviceStream.listen(_merge);
      });
    });
  }

  final Ref _ref;

  void _merge(DeviceModel incoming) {
    final index = state.indexWhere((d) => d.ipAddress == incoming.ipAddress);
    if (index == -1) {
      state = [...state, incoming];
      return;
    }
    final existing = state[index];
    final merged = existing.copyWith(
      deviceId: incoming.deviceId ?? existing.deviceId,
      hostname: incoming.hostname ?? existing.hostname,
      macAddress: incoming.macAddress ?? existing.macAddress,
      operatingSystem: incoming.operatingSystem ?? existing.operatingSystem,
      deviceType: incoming.isVoidLanPeer ? incoming.deviceType : existing.deviceType,
      status: DeviceStatus.online,
      pingMs: incoming.pingMs ?? existing.pingMs,
      isVoidLanPeer: existing.isVoidLanPeer || incoming.isVoidLanPeer,
      lastSeen: incoming.lastSeen ?? existing.lastSeen,
    );
    final updated = [...state];
    updated[index] = merged;
    state = updated;
  }

  Future<void> scan() async {
    final identity = await _ref.read(deviceIdentityProvider.future);
    await _ref.read(lanDiscoveryServiceProvider).scan(
          localDeviceId: identity.id,
          localDeviceName: identity.name,
        );
  }

  void clearStale() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    state = state
        .where((d) => d.lastSeen == null || d.lastSeen!.isAfter(cutoff))
        .toList();
  }
}

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, List<DeviceModel>>(
        (ref) => DeviceListNotifier(ref));

final isScanningProvider = StateProvider<bool>((ref) => false);
final deviceSearchQueryProvider = StateProvider<String>((ref) => '');
final deviceSortModeProvider = StateProvider<DeviceSortMode>((ref) => DeviceSortMode.name);

/// Filtered + sorted view of [deviceListProvider] driven by the search
/// box and sort selector in the LAN Explorer app bar.
final visibleDevicesProvider = Provider<List<DeviceModel>>((ref) {
  final devices = ref.watch(deviceListProvider);
  final query = ref.watch(deviceSearchQueryProvider).toLowerCase();
  final sortMode = ref.watch(deviceSortModeProvider);

  var filtered = devices.where((d) {
    if (query.isEmpty) return true;
    return d.displayName.toLowerCase().contains(query) ||
        d.ipAddress.contains(query);
  }).toList();

  filtered.sort((a, b) {
    switch (sortMode) {
      case DeviceSortMode.name:
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      case DeviceSortMode.ip:
        return _ipSortKey(a.ipAddress).compareTo(_ipSortKey(b.ipAddress));
      case DeviceSortMode.ping:
        return (a.pingMs ?? 999999).compareTo(b.pingMs ?? 999999);
      case DeviceSortMode.status:
        return a.status.index.compareTo(b.status.index);
    }
  });

  return filtered;
});

int _ipSortKey(String ip) {
  final parts = ip.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return 0;
  return (parts[0]! << 24) | (parts[1]! << 16) | (parts[2]! << 8) | parts[3]!;
}
