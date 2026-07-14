import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/utils/network_utils.dart';
import 'network_providers.dart';

enum ConnectionQuality { unknown, poor, fair, good }

class NetworkStatusSnapshot {
  const NetworkStatusSnapshot({
    required this.connectionType,
    required this.ssid,
    required this.localIp,
    required this.gatewayIp,
    required this.subnetMask,
    required this.quality,
    required this.averagePingMs,
  });

  final String connectionType;
  final String? ssid;
  final String? localIp;
  final String? gatewayIp;
  final String subnetMask;
  final ConnectionQuality quality;
  final int? averagePingMs;
}

final networkStatusProvider = FutureProvider.autoDispose<NetworkStatusSnapshot>((ref) async {
  final connectivityResults = await Connectivity().checkConnectivity();
  final info = NetworkInfo();

  final connectionType = connectivityResults.contains(ConnectivityResult.wifi)
      ? 'Wi-Fi'
      : connectivityResults.contains(ConnectivityResult.ethernet)
          ? 'Ethernet'
          : connectivityResults.contains(ConnectivityResult.mobile)
              ? 'Mobile hotspot'
              : 'Unknown';

  String? ssid;
  try {
    final rawSsid = await info.getWifiName();
    ssid = rawSsid?.replaceAll('"', '');
  } catch (_) {
    ssid = null;
  }

  String? gatewayIp;
  try {
    gatewayIp = await info.getWifiGatewayIP();
  } catch (_) {
    gatewayIp = null;
  }

  final localIp = await NetworkUtils.getLocalIPv4();
  final subnetMask = await NetworkUtils.getSubnetMask();

  final devices = ref.watch(deviceListProvider);
  final pings = devices.map((d) => d.pingMs).whereType<int>().toList();
  final averagePing =
      pings.isEmpty ? null : (pings.reduce((a, b) => a + b) / pings.length).round();

  final quality = averagePing == null
      ? ConnectionQuality.unknown
      : averagePing < 20
          ? ConnectionQuality.good
          : averagePing < 80
              ? ConnectionQuality.fair
              : ConnectionQuality.poor;

  return NetworkStatusSnapshot(
    connectionType: connectionType,
    ssid: ssid,
    localIp: localIp,
    gatewayIp: gatewayIp,
    subnetMask: subnetMask,
    quality: quality,
    averagePingMs: averagePing,
  );
});
