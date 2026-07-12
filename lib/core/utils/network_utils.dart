import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

/// Helper functions for resolving the local network interface and
/// enumerating the addresses that belong to the same /24 subnet.
class NetworkUtils {
  NetworkUtils._();

  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Returns this device's current IPv4 address on the active interface,
  /// or `null` if it cannot be determined (e.g. no Wi-Fi/Ethernet link).
  static Future<String?> getLocalIPv4() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {
      // Fall through to the NetworkInterface probe below.
    }
    return _firstInterfaceAddress();
  }

  static Future<String?> _firstInterfaceAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  /// Returns the subnet mask for the active interface, defaulting to a
  /// standard /24 (255.255.255.0) when it cannot be resolved.
  static Future<String> getSubnetMask() async {
    try {
      final mask = await _networkInfo.getWifiSubmask();
      if (mask != null && mask.isNotEmpty) return mask;
    } catch (_) {
      // ignore and fall back
    }
    return '255.255.255.0';
  }

  /// Given a local IPv4 (e.g. 192.168.1.42) and a subnet mask, returns
  /// every host address in that subnet excluding the network/broadcast
  /// addresses and the local address itself.
  static List<String> hostsInSubnet(String localIp, String mask) {
    final ipParts = localIp.split('.').map(int.parse).toList();
    final maskParts = mask.split('.').map(int.parse).toList();
    if (ipParts.length != 4 || maskParts.length != 4) {
      return _fallbackClassC(localIp);
    }

    final network = List<int>.generate(4, (i) => ipParts[i] & maskParts[i]);
    final hostBits = maskParts
        .map((m) => 8 - _popcount(m))
        .fold<int>(0, (a, b) => a + b);

    // Guard against scanning huge ranges (anything bigger than /22).
    if (hostBits > 10) {
      return _fallbackClassC(localIp);
    }

    final totalHosts = (1 << hostBits) - 2; // exclude network + broadcast
    final base = (network[0] << 24) | (network[1] << 16) |
        (network[2] << 8) | network[3];

    final result = <String>[];
    for (var h = 1; h <= totalHosts; h++) {
      final addrInt = base + h;
      final candidate = [
        (addrInt >> 24) & 0xFF,
        (addrInt >> 16) & 0xFF,
        (addrInt >> 8) & 0xFF,
        addrInt & 0xFF,
      ].join('.');
      if (candidate != localIp) result.add(candidate);
    }
    return result;
  }

  static List<String> _fallbackClassC(String localIp) {
    final parts = localIp.split('.');
    if (parts.length != 4) return [];
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    return [
      for (var i = 1; i < 255; i++)
        if ('$prefix.$i' != localIp) '$prefix.$i'
    ];
  }

  static int _popcount(int value) {
    var count = 0;
    var v = value;
    while (v != 0) {
      count += v & 1;
      v >>= 1;
    }
    return count;
  }
}
