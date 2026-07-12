import 'package:flutter/foundation.dart';

/// Broad category used to pick an icon and to bucket devices in the UI.
enum DeviceType { desktop, mobile, server, router, unknown }

/// Online/offline/pairing state of a discovered device.
enum DeviceStatus { online, offline, pairing, paired }

/// Immutable representation of a peer discovered on the local network.
///
/// Instances are produced by [LanDiscoveryService] and by the mDNS
/// advertisement listener, then merged into a single provider-managed
/// list keyed by [ipAddress].
@immutable
class DeviceModel {
  const DeviceModel({
    required this.ipAddress,
    required this.status,
    this.deviceId,
    this.hostname,
    this.macAddress,
    this.operatingSystem,
    this.deviceType = DeviceType.unknown,
    this.pingMs,
    this.isVoidLanPeer = false,
    this.lastSeen,
  });

  final String ipAddress;
  final String? deviceId;
  final String? hostname;
  final String? macAddress;
  final String? operatingSystem;
  final DeviceType deviceType;
  final DeviceStatus status;
  final int? pingMs;

  /// True when the device responded to the VOID LAN discovery handshake,
  /// meaning file transfer and chat are available (not just a bare host).
  final bool isVoidLanPeer;

  final DateTime? lastSeen;

  String get displayName =>
      hostname != null && hostname!.trim().isNotEmpty ? hostname! : ipAddress;

  DeviceModel copyWith({
    String? deviceId,
    String? hostname,
    String? macAddress,
    String? operatingSystem,
    DeviceType? deviceType,
    DeviceStatus? status,
    int? pingMs,
    bool? isVoidLanPeer,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      ipAddress: ipAddress,
      deviceId: deviceId ?? this.deviceId,
      hostname: hostname ?? this.hostname,
      macAddress: macAddress ?? this.macAddress,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      deviceType: deviceType ?? this.deviceType,
      status: status ?? this.status,
      pingMs: pingMs ?? this.pingMs,
      isVoidLanPeer: isVoidLanPeer ?? this.isVoidLanPeer,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceModel && other.ipAddress == ipAddress;

  @override
  int get hashCode => ipAddress.hashCode;
}
