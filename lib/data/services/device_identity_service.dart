import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';

/// Resolves and persists a stable identifier for this installation.
///
/// The ID is generated once with [Uuid.v4] and stored in
/// [FlutterSecureStorage] so it survives app restarts; peers use it to
/// distinguish "the same device reconnecting" from "a different device
/// on this IP" (relevant since DHCP can reassign addresses).
class DeviceIdentityService {
  const DeviceIdentityService();

  static const _storage = FlutterSecureStorage();

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: AppConstants.secureKeyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = const Uuid().v4();
    await _storage.write(
        key: AppConstants.secureKeyDeviceId, value: generated);
    return generated;
  }
}
