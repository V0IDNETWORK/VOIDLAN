import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import 'peer_connection.dart';

/// Owns the single TCP control-port server socket and every active
/// [PeerConnection] (inbound or outbound), keyed by remote IP.
///
/// This is the "reliable TCP with automatic reconnection, multiple
/// simultaneous clients, heartbeat/keep-alive" layer the rest of the
/// app (messenger, pairing, transfer offers) is built on top of. File
/// bytes never travel over these sockets — see [FileTransferService]
/// for the dedicated transfer-port connections.
class ConnectionManager {
  ConnectionManager({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  ServerSocket? _server;
  final Map<String, PeerConnection> _connections = {};
  final Map<String, Timer> _reconnectTimers = {};
  final _newConnectionController = StreamController<PeerConnection>.broadcast();

  /// Emits every newly-established connection, inbound or outbound, once
  /// it is ready to send/receive.
  Stream<PeerConnection> get onConnection => _newConnectionController.stream;

  Map<String, PeerConnection> get activeConnections =>
      Map.unmodifiable(_connections);

  /// Starts the control-port [ServerSocket]. Accepts unlimited
  /// concurrent inbound connections; each is wrapped in its own
  /// [PeerConnection] and registered under the caller's IP.
  Future<void> startServer() async {
    if (_server != null) return;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4,
        AppConstants.controlPort, shared: true);
    _logger.i('Control server listening on ${AppConstants.controlPort}');
    _server!.listen((socket) {
      final ip = socket.remoteAddress.address;
      _register(ip, socket, isInbound: true);
    }, onError: (e) => _logger.e('Server socket error: $e'));
  }

  /// Establishes (or returns the existing) connection to [ip]. If the
  /// peer is unreachable, schedules a reconnect attempt every
  /// [AppConstants.reconnectDelay] until [disconnect] is called for
  /// that IP or a connection succeeds.
  Future<PeerConnection?> connectTo(String ip) async {
    final existing = _connections[ip];
    if (existing != null && existing.isAlive) return existing;

    try {
      final socket = await Socket.connect(ip, AppConstants.controlPort,
          timeout: const Duration(seconds: 5));
      return _register(ip, socket, isInbound: false);
    } catch (e) {
      _logger.w('Connect to $ip failed, scheduling retry: $e');
      _scheduleReconnect(ip);
      return null;
    }
  }

  PeerConnection _register(String ip, Socket socket,
      {required bool isInbound}) {
    _connections[ip]?.close();
    final conn = PeerConnection(socket, remoteIp: ip, logger: _logger);
    _connections[ip] = conn;
    conn.onDisconnected.listen((_) {
      _connections.remove(ip);
      // Only outbound (client-initiated) links are auto-reconnected;
      // inbound links are re-established by the peer's own client side.
      if (!isInbound) _scheduleReconnect(ip);
    });
    _newConnectionController.add(conn);
    return conn;
  }

  void _scheduleReconnect(String ip) {
    _reconnectTimers[ip]?.cancel();
    _reconnectTimers[ip] = Timer(AppConstants.reconnectDelay, () async {
      _reconnectTimers.remove(ip);
      if (_connections[ip]?.isAlive ?? false) return;
      await connectTo(ip);
    });
  }

  /// Stops retrying and closes any live link to [ip].
  void disconnect(String ip) {
    _reconnectTimers.remove(ip)?.cancel();
    _connections.remove(ip)?.close();
  }

  PeerConnection? connectionFor(String ip) => _connections[ip];

  Future<void> dispose() async {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    for (final conn in _connections.values) {
      await conn.close();
    }
    _connections.clear();
    await _server?.close();
    await _newConnectionController.close();
  }
}
