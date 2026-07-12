import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams whether this device currently has a Wi-Fi or Ethernet link.
/// LAN Explorer uses this to show a banner instead of an empty,
/// confusing device list when there is no local network to scan.
final hasLanConnectionProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(_hasLanLink);
});

bool _hasLanLink(List<ConnectivityResult> results) {
  return results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
}
