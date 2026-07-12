import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import 'tcp_framing.dart';

/// Wraps a single connected [Socket] to a peer's control port with:
///
///  * length-prefixed JSON framing (via [FrameCodec]/[FrameDecoder])
///  * a periodic heartbeat with a timeout that marks the link dead
///  * a broadcast stream of decoded JSON messages for callers to
///    subscribe to (chat, typing indicators, transfer offers, …)
///
/// One [PeerConnection] exists per remote IP for the lifetime of that
/// link; [TcpServerService] and [TcpClientService] both produce them
/// through the same code path so inbound and outbound links behave
/// identically.
class PeerConnection {
  PeerConnection(this.socket, {required this.remoteIp, Logger? logger})
      : _logger = logger ?? Logger() {
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
    _statusController = StreamController<bool>.broadcast();
    _listen();
    _startHeartbeat();
  }

  final Socket socket;
  final String remoteIp;
  final Logger _logger;

  late final StreamController<Map<String, dynamic>> _messageController;
  late final StreamController<bool> _statusController;

  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  bool _alive = true;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Emits `false` exactly once, when the connection is considered dead
  /// (socket closed or heartbeat timeout elapsed).
  Stream<bool> get onDisconnected => _statusController.stream;

  bool get isAlive => _alive;

  void _listen() {
    socket.cast<List<int>>().transform(FrameDecoder()).listen(
      (frame) {
        try {
          final json = jsonDecode(utf8.decode(frame)) as Map<String, dynamic>;
          if (json['type'] == 'heartbeat') {
            send({'type': 'heartbeat_ack'});
            return;
          }
          if (json['type'] == 'heartbeat_ack') {
            _heartbeatTimeoutTimer?.cancel();
            return;
          }
          _messageController.add(json);
        } catch (e) {
          _logger.w('Dropped malformed frame from $remoteIp: $e');
        }
      },
      onError: (_) => _markDead(),
      onDone: _markDead,
      cancelOnError: false,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(AppConstants.heartbeatInterval, (_) {
      if (!_alive) return;
      send({'type': 'heartbeat'});
      _heartbeatTimeoutTimer?.cancel();
      _heartbeatTimeoutTimer = Timer(AppConstants.heartbeatTimeout, _markDead);
    });
  }

  /// Sends a JSON control message to the peer. Silently no-ops once the
  /// connection has been marked dead to avoid throwing on a closed
  /// socket from a caller that hasn't reacted to [onDisconnected] yet.
  void send(Map<String, dynamic> json) {
    if (!_alive) return;
    try {
      socket.add(FrameCodec.encodeJson(json));
    } catch (e) {
      _logger.w('Send failed to $remoteIp: $e');
      _markDead();
    }
  }

  void _markDead() {
    if (!_alive) return;
    _alive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimeoutTimer?.cancel();
    _statusController.add(false);
    socket.destroy();
  }

  Future<void> close() async {
    _markDead();
    await _messageController.close();
    await _statusController.close();
  }
}
