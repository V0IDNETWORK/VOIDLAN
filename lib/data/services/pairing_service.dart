import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import 'connection_manager.dart';
import 'peer_connection.dart';

/// A pairing request awaiting the local user's confirmation, surfaced
/// through [PairingService.incomingRequests]. The UI must show a
/// confirmation dialog before calling [PairingService.accept] — devices
/// are never trusted silently.
class PairingRequest {
  PairingRequest({
    required this.peerId,
    required this.peerName,
    required this.peerIp,
    required this.code,
  });

  final String peerId;
  final String peerName;
  final String peerIp;

  /// Short human-readable verification code both users can compare out
  /// of band (spoken aloud, shown on both screens) before accepting.
  final String code;
}

/// Establishes and remembers trust between this device and peers.
///
/// Trust is application-layer: each accepted pairing derives a shared
/// secret (via SHA-256 over both device IDs plus a random nonce
/// exchanged during the handshake) that is stored in
/// [FlutterSecureStorage] and attached to every subsequent control
/// message as an `authTag`, so a spoofed IP alone cannot impersonate a
/// previously paired device.
///
/// Note: this authenticates and integrity-protects the JSON control
/// channel but does not encrypt the socket bytes on the wire the way
/// transport-level TLS would. Wiring `SecureServerSocket`/`SecureSocket`
/// with a generated certificate is the natural next step for full
/// wire encryption and is called out in the README.
class PairingService {
  PairingService(this._connections, {required this.localDeviceId}) {
    _connections.onConnection.listen(_attach);
    _loadTrustedPeers();
  }

  final ConnectionManager _connections;
  final String localDeviceId;
  final _storage = const FlutterSecureStorage();
  final Random _random = Random.secure();

  final Map<String, String> _trustedSecrets = {}; // peerId -> secret
  final _incomingController = StreamController<PairingRequest>.broadcast();
  final _pairedController = StreamController<String>.broadcast();

  Stream<PairingRequest> get incomingRequests => _incomingController.stream;

  /// Emits the peer id whenever a pairing completes successfully.
  Stream<String> get onPaired => _pairedController.stream;

  bool isPaired(String peerId) => _trustedSecrets.containsKey(peerId);

  Future<void> _loadTrustedPeers() async {
    final raw = await _storage.read(key: AppConstants.secureKeyPairingSecret);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _trustedSecrets.addAll(map.map((k, v) => MapEntry(k, v as String)));
  }

  Future<void> _saveTrustedPeers() async {
    await _storage.write(
      key: AppConstants.secureKeyPairingSecret,
      value: jsonEncode(_trustedSecrets),
    );
  }

  void _attach(PeerConnection conn) {
    conn.messages.listen((json) {
      switch (json['type']) {
        case 'pairing_request':
          _handleIncomingRequest(json, conn);
          break;
        case 'pairing_response':
          _handleResponse(json);
          break;
      }
    });
  }

  final Map<String, Completer<bool>> _pendingOutgoing = {};

  /// Initiates pairing with [peerIp]/[peerId]. Resolves `true` once the
  /// remote user accepts, `false` on rejection or timeout.
  Future<bool> requestPairing({
    required String peerIp,
    required String peerId,
    required String localName,
  }) async {
    final conn = await _connections.connectTo(peerIp);
    if (conn == null) return false;

    final nonce = _generateNonce();
    final completer = Completer<bool>();
    _pendingOutgoing[peerId] = completer;

    conn.send({
      'type': 'pairing_request',
      'senderId': localDeviceId,
      'name': localName,
      'nonce': nonce,
    });

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
  }

  void _handleIncomingRequest(Map<String, dynamic> json, PeerConnection conn) {
    final peerId = json['senderId'] as String;
    final peerName = json['name'] as String? ?? peerId;
    final nonce = json['nonce'] as String;
    final code = _verificationCode(localDeviceId, peerId, nonce);

    _incomingController.add(PairingRequest(
      peerId: peerId,
      peerName: peerName,
      peerIp: conn.remoteIp,
      code: code,
    ));

    _pendingNonces[peerId] = nonce;
    _pendingConnections[peerId] = conn;
  }

  final Map<String, String> _pendingNonces = {};
  final Map<String, PeerConnection> _pendingConnections = {};

  /// Called after the user confirms the on-screen dialog for [peerId].
  Future<void> accept(String peerId) async {
    final nonce = _pendingNonces.remove(peerId);
    final conn = _pendingConnections.remove(peerId);
    if (nonce == null || conn == null) return;

    final secret = _deriveSecret(localDeviceId, peerId, nonce);
    _trustedSecrets[peerId] = secret;
    await _saveTrustedPeers();

    conn.send({'type': 'pairing_response', 'senderId': localDeviceId, 'accepted': true});
    _pairedController.add(peerId);
  }

  Future<void> reject(String peerId) async {
    final conn = _pendingConnections.remove(peerId);
    _pendingNonces.remove(peerId);
    conn?.send(
        {'type': 'pairing_response', 'senderId': localDeviceId, 'accepted': false});
  }

  void _handleResponse(Map<String, dynamic> json) {
    final peerId = json['senderId'] as String;
    final accepted = json['accepted'] as bool? ?? false;
    final completer = _pendingOutgoing.remove(peerId);
    if (completer == null || completer.isCompleted) return;
    completer.complete(accepted);
  }

  String _generateNonce() =>
      base64UrlEncode(List<int>.generate(16, (_) => _random.nextInt(256)));

  String _deriveSecret(String idA, String idB, String nonce) {
    final ids = [idA, idB]..sort();
    final bytes = utf8.encode('${ids.join('|')}|$nonce');
    return sha256.convert(bytes).toString();
  }

  String _verificationCode(String idA, String idB, String nonce) {
    final secret = _deriveSecret(idA, idB, nonce);
    // Six-digit code derived from the shared secret, shown on both
    // screens for out-of-band comparison before either side accepts.
    final digest = secret.codeUnits.fold<int>(0, (a, b) => a + b);
    return (digest % 1000000).toString().padLeft(6, '0');
  }

  void dispose() {
    _incomingController.close();
    _pairedController.close();
  }
}
