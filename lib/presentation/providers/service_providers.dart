import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../data/services/connection_manager.dart';
import '../../data/services/device_identity_service.dart';
import '../../data/services/file_transfer_service.dart';
import '../../data/services/lan_discovery_service.dart';
import '../../data/services/local_server_service.dart';
import '../../data/services/messenger_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/pairing_service.dart';

/// Shared [Logger] instance used across the data layer.
final loggerProvider = Provider<Logger>((ref) => Logger(
      printer: PrettyPrinter(methodCount: 0, colors: false),
    ));

final deviceIdentityServiceProvider =
    Provider<DeviceIdentityService>((ref) => const DeviceIdentityService());

/// Resolves once at startup and is cached for the app's lifetime — this
/// device's stable ID and human-readable name shown to peers.
final deviceIdentityProvider = FutureProvider<({String id, String name})>((ref) async {
  final identity = ref.watch(deviceIdentityServiceProvider);
  final discovery = ref.watch(lanDiscoveryServiceProvider);
  final id = await identity.getOrCreateDeviceId();
  final name = await discovery.resolveLocalDeviceName();
  return (id: id, name: name);
});

final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final manager = ConnectionManager(logger: ref.watch(loggerProvider));
  ref.onDispose(manager.dispose);
  return manager;
});

final lanDiscoveryServiceProvider = Provider<LanDiscoveryService>((ref) {
  final service = LanDiscoveryService(logger: ref.watch(loggerProvider));
  ref.onDispose(service.dispose);
  return service;
});

final fileTransferServiceProvider = Provider<FileTransferService>((ref) {
  final service = FileTransferService(logger: ref.watch(loggerProvider));
  ref.onDispose(service.dispose);
  return service;
});

final pairingServiceProvider = Provider<PairingService?>((ref) {
  final identity = ref.watch(deviceIdentityProvider).valueOrNull;
  if (identity == null) return null;
  final service = PairingService(
    ref.watch(connectionManagerProvider),
    localDeviceId: identity.id,
  );
  ref.onDispose(service.dispose);
  return service;
});

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final messengerServiceProvider = Provider<MessengerService?>((ref) {
  final identity = ref.watch(deviceIdentityProvider).valueOrNull;
  if (identity == null) return null;
  final service = MessengerService(
    ref.watch(connectionManagerProvider),
    localDeviceId: identity.id,
    logger: ref.watch(loggerProvider),
  );
  final notifications = ref.watch(notificationServiceProvider);
  service.messageStream.listen((message) {
    if (message.isOutgoing) return;
    notifications.showMessageNotification(
      senderName: message.senderId,
      preview: message.text ?? '[${message.type.name}]',
    );
  });
  ref.onDispose(service.dispose);
  return service;
});

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  return LocalServerService(
    connectionManager: ref.watch(connectionManagerProvider),
    fileTransferService: ref.watch(fileTransferServiceProvider),
    discoveryService: ref.watch(lanDiscoveryServiceProvider),
    logger: ref.watch(loggerProvider),
  );
});

/// Boots the local server exactly once the device identity is resolved.
/// UI code watches this to gate features that require the server (e.g.
/// showing the LAN Explorer scan button) until it completes.
final serverBootProvider = FutureProvider<void>((ref) async {
  final identity = await ref.watch(deviceIdentityProvider.future);
  final server = ref.watch(localServerServiceProvider);
  await server.start(deviceId: identity.id, deviceName: identity.name);
});
