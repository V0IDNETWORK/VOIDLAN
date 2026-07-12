import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/pairing_service.dart';
import 'service_providers.dart';

final incomingPairingRequestProvider = StreamProvider<PairingRequest>((ref) {
  final service = ref.watch(pairingServiceProvider);
  if (service == null) return const Stream.empty();
  return service.incomingRequests;
});

/// Tracks which peer IDs this device has completed pairing with, purely
/// for UI badges (a "paired" checkmark on the device tile/details page).
class PairedPeersNotifier extends StateNotifier<Set<String>> {
  PairedPeersNotifier(this._ref) : super({}) {
    _ref.listen(pairingServiceProvider, (_, service) {
      service?.onPaired.listen((peerId) {
        state = {...state, peerId};
      });
    }, fireImmediately: true);
  }

  final Ref _ref;
}

final pairedPeersProvider =
    StateNotifierProvider<PairedPeersNotifier, Set<String>>(
        (ref) => PairedPeersNotifier(ref));
