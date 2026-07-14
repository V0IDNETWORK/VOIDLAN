import 'package:flutter/foundation.dart';

enum TransferDirection { send, receive }

enum TransferState {
  queued,
  connecting,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}

/// Tracks the live progress of a single file transfer (one file per task;
/// multi-file operations enqueue one [TransferTaskModel] each).
@immutable
class TransferTaskModel {
  const TransferTaskModel({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    required this.direction,
    required this.peerIp,
    required this.peerName,
    this.localPath,
    this.transferredBytes = 0,
    this.state = TransferState.queued,
    this.speedBytesPerSec = 0,
    this.startedAt,
    this.errorMessage,
  });

  final String id;
  final String fileName;
  final int totalBytes;
  final TransferDirection direction;
  final String peerIp;
  final String peerName;
  final String? localPath;
  final int transferredBytes;
  final TransferState state;
  final double speedBytesPerSec;
  final DateTime? startedAt;
  final String? errorMessage;

  double get progress =>
      totalBytes == 0 ? 0 : (transferredBytes / totalBytes).clamp(0, 1);

  Duration? get eta {
    if (speedBytesPerSec <= 0) return null;
    final remaining = totalBytes - transferredBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / speedBytesPerSec).round());
  }

  TransferTaskModel copyWith({
    int? transferredBytes,
    TransferState? state,
    double? speedBytesPerSec,
    DateTime? startedAt,
    String? errorMessage,
    String? localPath,
  }) {
    return TransferTaskModel(
      id: id,
      fileName: fileName,
      totalBytes: totalBytes,
      direction: direction,
      peerIp: peerIp,
      peerName: peerName,
      localPath: localPath ?? this.localPath,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      state: state ?? this.state,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      startedAt: startedAt ?? this.startedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) => other is TransferTaskModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'totalBytes': totalBytes,
        'direction': direction.name,
        'peerIp': peerIp,
        'peerName': peerName,
        'localPath': localPath,
        'transferredBytes': transferredBytes,
        'state': state.name,
        'startedAt': startedAt?.toIso8601String(),
        'errorMessage': errorMessage,
      };

  factory TransferTaskModel.fromJson(Map<String, dynamic> json) {
    return TransferTaskModel(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      totalBytes: json['totalBytes'] as int,
      direction: TransferDirection.values.firstWhere((d) => d.name == json['direction']),
      peerIp: json['peerIp'] as String,
      peerName: json['peerName'] as String,
      localPath: json['localPath'] as String?,
      transferredBytes: json['transferredBytes'] as int? ?? 0,
      state: TransferState.values.firstWhere((s) => s.name == json['state'],
          orElse: () => TransferState.failed),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
