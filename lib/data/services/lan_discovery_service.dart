import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/network_utils.dart';
import '../models/device_model.dart';

/// Discovers peers on the local subnet using two complementary
/// strategies:
///
///  1. A UDP broadcast handshake (fast path) — every VOID LAN instance
///     listens on [AppConstants.discoveryPort] and answers broadcast
///     "hello" packets with its device metadata. UDP here is used only
///     for presence discovery, never for chat or file bytes.
///  2. A concurrent TCP-connect sweep of the /24 (or smaller, computed)
///     subnet against [AppConstants.controlPort] as a fallback for
///     networks that block broadcast/multicast traffic, and to surface
///     plain (non-VOID-LAN) hosts as "online" devices with limited info.
///
/// Results are streamed incrementally via [deviceStream] so the UI can
/// render devices as they are found instead of waiting for the full
/// sweep to finish.
class LanDiscoveryService {
  LanDiscoveryService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final _deviceController = StreamController<DeviceModel>.broadcast();
  RawDatagramSocket? _udpSocket;
  Future<void>? _socketReady;
  bool _scanning = false;

  // Set once by startResponder and reused to answer other instances'
  // discovery broadcasts for as long as the app runs.
  String? _localDeviceId;
  String? _localDeviceName;

  Stream<DeviceModel> get deviceStream => _deviceController.stream;
  bool get isScanning => _scanning;

  /// Runs one full discovery pass. Safe to call repeatedly (e.g. from a
  /// pull-to-refresh); a second call while one is in flight is ignored.
  Future<void> scan({String? localDeviceId, String? localDeviceName}) async {
    if (_scanning) return;
    _scanning = true;
    try {
      final localIp = await NetworkUtils.getLocalIPv4();
      if (localIp == null) {
        _logger.w('No active network interface found; aborting scan.');
        return;
      }
      final mask = await NetworkUtils.getSubnetMask();
      final hosts = NetworkUtils.hostsInSubnet(localIp, mask);

      await Future.wait([
        _broadcastHandshake(localDeviceId, localDeviceName),
        _tcpSweep(hosts),
      ]);
    } finally {
      _scanning = false;
    }
  }

  /// Binds the discovery UDP socket and attaches its single, permanent
  /// listener exactly once. `RawDatagramSocket`'s stream is
  /// single-subscription, so both the always-on responder (answering
  /// other instances' broadcasts) and the scan's reply-collection path
  /// share this one listener instead of each calling `.listen()`
  /// independently — calling it twice is what previously crashed with
  /// "Bad state: Stream has already been listened to."
  Future<void> _ensureSocketReady() {
    return _socketReady ??= () async {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen(_onDatagramEvent, onError: (e) {
        _logger.w('Discovery socket error: $e');
      });
    }();
  }

  void _onDatagramEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dgram = _udpSocket?.receive();
    if (dgram == null) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(dgram.data)) as Map<String, dynamic>;
    } catch (e) {
      _logger.d('Malformed discovery packet ignored: $e');
      return;
    }

    if (data['magic'] == AppConstants.discoveryMagic) {
      _replyToHello(dgram, data);
    } else if (data['magic'] == AppConstants.discoveryAck) {
      _handleDiscoveryReply(dgram, data);
    }
  }

  void _replyToHello(Datagram dgram, Map<String, dynamic> data) {
    if (_localDeviceId == null || _localDeviceName == null) return;
    final reply = jsonEncode({
      'magic': AppConstants.discoveryAck,
      'deviceId': _localDeviceId,
      'name': _localDeviceName,
      'platform': Platform.operatingSystem,
    });
    _udpSocket!.send(utf8.encode(reply), dgram.address, AppConstants.discoveryPort);
  }

  /// Sends a UDP broadcast hello; replies arrive through the shared
  /// listener set up by [_ensureSocketReady] and are pushed to
  /// [deviceStream] by [_handleDiscoveryReply].
  Future<void> _broadcastHandshake(
      String? localDeviceId, String? localDeviceName) async {
    try {
      await _ensureSocketReady();
      final payload = jsonEncode({
        'magic': AppConstants.discoveryMagic,
        'deviceId': localDeviceId,
        'name': localDeviceName,
        'platform': Platform.operatingSystem,
      });
      _udpSocket!.send(
          utf8.encode(payload), InternetAddress('255.255.255.255'), AppConstants.discoveryPort);
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      _logger.w('UDP discovery unavailable: $e');
    }
  }

  void _handleDiscoveryReply(Datagram dgram, Map<String, dynamic> data) {
    _deviceController.add(DeviceModel(
      ipAddress: dgram.address.address,
      deviceId: data['deviceId'] as String?,
      hostname: data['name'] as String?,
      operatingSystem: data['platform'] as String?,
      deviceType: _typeFromPlatform(data['platform'] as String?),
      status: DeviceStatus.online,
      isVoidLanPeer: true,
      lastSeen: DateTime.now(),
    ));
  }

  /// Registers this device's identity so the shared listener can answer
  /// other instances' discovery broadcasts, and ensures the socket is
  /// bound. Call once at app startup alongside the local server.
  Future<void> startResponder({
    required String deviceId,
    required String deviceName,
  }) async {
    _localDeviceId = deviceId;
    _localDeviceName = deviceName;
    await _ensureSocketReady();
  }

  /// Concurrently attempts a short TCP connect to every candidate host's
  /// control port. A successful connect proves the host is online even
  /// if it isn't running VOID LAN; round-trip time is reported as ping.
  Future<void> _tcpSweep(List<String> hosts) async {
    const batchSize = 32;
    for (var i = 0; i < hosts.length; i += batchSize) {
      final batch = hosts.skip(i).take(batchSize);
      await Future.wait(batch.map(probeHost));
    }
  }

  /// Attempts a short TCP connect to [ip]'s control port. Used by the
  /// subnet sweep and also exposed directly for manual "connect by IP"
  /// entry — the same success/failure and MAC-lookup logic applies
  /// whether the address came from a sweep or the user typed it in,
  /// which matters on networks (e.g. some mobile hotspots) where
  /// broadcast/multicast discovery is blocked but direct TCP isn't.
  Future<bool> probeHost(String ip, {Duration? timeout}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        ip,
        AppConstants.controlPort,
        timeout: timeout ?? AppConstants.scanConnectTimeout,
      );
      stopwatch.stop();
      socket.destroy();
      final mac = await _lookupMac(ip);
      _deviceController.add(DeviceModel(
        ipAddress: ip,
        pingMs: stopwatch.elapsedMilliseconds,
        macAddress: mac,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
      ));
      return true;
    } catch (_) {
      // Host did not answer on the control port within the timeout;
      // absence == offline for scan purposes, but manual-connect calls
      // still get an honest false rather than a silent no-op.
      return false;
    }
  }

  /// Best-effort MAC address resolution via the OS ARP/neighbor table.
  /// Requires the OS to have already ARPed the target (true right after
  /// a successful TCP connect). Returns null when the platform tool is
  /// unavailable or the entry cannot be parsed.
  Future<String?> _lookupMac(String ip) async {
    try {
      ProcessResult result;
      if (Platform.isWindows) {
        result = await Process.run('arp', ['-a', ip]);
      } else {
        result = await Process.run('arp', ['-n', ip]);
      }
      if (result.exitCode != 0) return null;
      final output = result.stdout.toString();
      final macRegex = RegExp(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');
      final match = macRegex.firstMatch(output);
      return match?.group(0)?.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  DeviceType _typeFromPlatform(String? platform) {
    switch (platform) {
      case 'windows':
      case 'linux':
      case 'macos':
        return DeviceType.desktop;
      case 'android':
      case 'ios':
        return DeviceType.mobile;
      default:
        return DeviceType.unknown;
    }
  }

  Future<String> resolveLocalDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        return w.computerName;
      } else if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      } else if (Platform.isLinux) {
        final l = await info.linuxInfo;
        return l.name;
      }
    } catch (_) {
      // fall through
    }
    return Platform.localHostname;
  }

  void dispose() {
    _udpSocket?.close();
    _udpSocket = null;
    _socketReady = null;
    _deviceController.close();
  }
}
