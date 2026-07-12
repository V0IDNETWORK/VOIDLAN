import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import 'connection_manager.dart';
import 'file_transfer_service.dart';
import 'lan_discovery_service.dart';

/// Starts the lightweight local server that lets this device be found
/// and communicated with by other VOID LAN instances: the TCP control
/// port (chat/pairing/heartbeat), the TCP transfer port (file bytes),
/// and the UDP discovery responder that answers other peers' broadcast
/// probes so this device shows up in their scan without them needing to
/// sweep the whole subnet.
class LocalServerService {
  LocalServerService({
    required this.connectionManager,
    required this.fileTransferService,
    required this.discoveryService,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final ConnectionManager connectionManager;
  final FileTransferService fileTransferService;
  final LanDiscoveryService discoveryService;
  final Logger _logger;

  bool _started = false;
  bool get isRunning => _started;

  Future<void> start({
    required String deviceId,
    required String deviceName,
  }) async {
    if (_started) return;

    final downloadsDir = await _resolveDownloadsDir();

    await connectionManager.startServer();
    await fileTransferService.startServer(downloadsDir: downloadsDir);
    await discoveryService.startResponder(
      deviceId: deviceId,
      deviceName: deviceName,
    );

    _started = true;
    _logger.i('VOID LAN local server is up as "$deviceName" ($deviceId)');
  }

  Future<String> _resolveDownloadsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/VoidLanReceived';
    final receivedDir = Directory(path);
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
    return path;
  }

  Future<void> stop() async {
    await connectionManager.dispose();
    await fileTransferService.dispose();
    discoveryService.dispose();
    _started = false;
  }
}
