import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/transfer_task_model.dart';
import 'tcp_framing.dart';

/// An inbound transfer request awaiting user confirmation, surfaced via
/// [FileTransferService.incomingRequests]. Nothing is written to disk
/// until [FileTransferService.acceptIncoming] is called — this is the
/// pairing/confirmation step required before any file lands on the
/// receiving device.
class IncomingTransferRequest {
  IncomingTransferRequest({
    required this.transferId,
    required this.fileName,
    required this.totalBytes,
    required this.senderIp,
  });

  final String transferId;
  final String fileName;
  final int totalBytes;
  final String senderIp;
}

class _PendingIncoming {
  _PendingIncoming({
    required this.socket,
    required this.fileDataStream,
    required this.downloadsDir,
    required this.fileName,
    required this.totalBytes,
    required this.senderIp,
  });

  final Socket socket;
  final Stream<List<int>> fileDataStream;
  final String downloadsDir;
  final String fileName;
  final int totalBytes;
  final String senderIp;
}

class _CancelToken {
  bool cancelled = false;
}

/// Handles the dedicated file-transfer TCP port. Each transfer opens a
/// fresh socket (never multiplexed with chat control traffic). The wire
/// format on that socket is simply:
///
/// `[4-byte length][JSON header frame] [raw file bytes from resumeOffset..end]`
///
/// Exactly one `socket.listen` is attached per incoming connection; a
/// small manual buffer demultiplexes the header frame from the raw
/// bytes that immediately follow it in the same TCP stream, since a
/// [Socket]'s stream can only ever be listened to once.
class FileTransferService {
  FileTransferService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;
  final _uuid = const Uuid();
  ServerSocket? _server;

  final _incomingRequestController =
      StreamController<IncomingTransferRequest>.broadcast();
  final _taskUpdateController = StreamController<TransferTaskModel>.broadcast();
  final Map<String, StreamSubscription> _activeStreams = {};
  final Map<String, IOSink> _openSinks = {};
  final Map<String, RandomAccessFile> _openReaders = {};
  final Map<String, _PendingIncoming> _pendingSockets = {};
  final Map<String, _CancelToken> _cancelTokens = {};

  Stream<IncomingTransferRequest> get incomingRequests =>
      _incomingRequestController.stream;

  /// Live progress updates for every task (send or receive), keyed by
  /// [TransferTaskModel.id]; the UI filters/aggregates this as needed.
  Stream<TransferTaskModel> get taskUpdates => _taskUpdateController.stream;

  Future<void> startServer({required String downloadsDir}) async {
    if (_server != null) return;
    _server = await ServerSocket.bind(
        InternetAddress.anyIPv4, AppConstants.transferPort, shared: true);
    _logger.i('Transfer server listening on ${AppConstants.transferPort}');
    _server!.listen((socket) => _handleIncomingSocket(socket, downloadsDir));
  }

  void _handleIncomingSocket(Socket socket, String downloadsDir) {
    final remoteIp = socket.remoteAddress.address;
    final headerCompleter = Completer<Map<String, dynamic>>();
    final fileDataController = StreamController<List<int>>();

    final buffer = BytesBuilder();
    var headerParsed = false;
    int? expectedLen;

    socket.listen(
      (chunk) {
        if (headerParsed) {
          fileDataController.add(chunk);
          return;
        }
        buffer.add(chunk);
        final bytes = buffer.toBytes();

        expectedLen ??= bytes.length >= 4
            ? ByteData.sublistView(Uint8List.fromList(bytes.sublist(0, 4)))
                .getUint32(0, Endian.big)
            : null;
        if (expectedLen == null) return;
        if (bytes.length < 4 + expectedLen!) return;

        final headerBytes = bytes.sublist(4, 4 + expectedLen!);
        final leftover = bytes.sublist(4 + expectedLen!);
        headerParsed = true;

        try {
          final header =
              jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
          headerCompleter.complete(header);
        } catch (e) {
          headerCompleter.completeError(e);
          return;
        }
        if (leftover.isNotEmpty) fileDataController.add(leftover);
      },
      onError: (e) {
        if (!headerCompleter.isCompleted) headerCompleter.completeError(e);
        fileDataController.addError(e);
      },
      onDone: () => fileDataController.close(),
      cancelOnError: true,
    );

    headerCompleter.future.then((header) {
      final transferId = header['transferId'] as String;
      final fileName = header['fileName'] as String;
      final totalBytes = header['totalBytes'] as int;

      _pendingSockets[transferId] = _PendingIncoming(
        socket: socket,
        fileDataStream: fileDataController.stream,
        downloadsDir: downloadsDir,
        fileName: fileName,
        totalBytes: totalBytes,
        senderIp: remoteIp,
      );

      _incomingRequestController.add(IncomingTransferRequest(
        transferId: transferId,
        fileName: fileName,
        totalBytes: totalBytes,
        senderIp: remoteIp,
      ));
    }).catchError((e) {
      _logger.w('Bad incoming transfer handshake from $remoteIp: $e');
      socket.destroy();
    });
  }

  /// Confirms an [IncomingTransferRequest], writing the file into
  /// `downloadsDir/fileName` (resuming a partial `.part` file left over
  /// from a previously interrupted transfer, if one exists).
  Future<void> acceptIncoming(String transferId) async {
    final pending = _pendingSockets.remove(transferId);
    if (pending == null) return;

    final destPath = p.join(pending.downloadsDir, pending.fileName);
    final partFile = File('$destPath.part');
    final resumeOffset = await partFile.exists() ? await partFile.length() : 0;

    pending.socket.add(FrameCodec.encodeJson({
      'status': 'ready',
      'resumeOffset': resumeOffset,
    }));

    final sink = partFile.openWrite(
        mode: resumeOffset > 0 ? FileMode.append : FileMode.write);
    _openSinks[transferId] = sink;

    var received = resumeOffset;
    var lastBytes = resumeOffset;
    var lastTime = DateTime.now();
    final startedAt = DateTime.now();

    _emit(TransferTaskModel(
      id: transferId,
      fileName: pending.fileName,
      totalBytes: pending.totalBytes,
      direction: TransferDirection.receive,
      peerIp: pending.senderIp,
      peerName: pending.senderIp,
      transferredBytes: received,
      state: TransferState.transferring,
      startedAt: startedAt,
    ));

    _activeStreams[transferId] = pending.fileDataStream.listen(
      (chunk) {
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds;
        if (elapsed >= 500) {
          final speed = (received - lastBytes) / (elapsed / 1000);
          lastBytes = received;
          lastTime = now;
          _emit(TransferTaskModel(
            id: transferId,
            fileName: pending.fileName,
            totalBytes: pending.totalBytes,
            direction: TransferDirection.receive,
            peerIp: pending.senderIp,
            peerName: pending.senderIp,
            transferredBytes: received,
            state: TransferState.transferring,
            speedBytesPerSec: speed,
            startedAt: startedAt,
          ));
        }
      },
      onDone: () async {
        await sink.close();
        _openSinks.remove(transferId);
        _activeStreams.remove(transferId);
        if (received >= pending.totalBytes) {
          await partFile.rename(destPath);
          _emit(TransferTaskModel(
            id: transferId,
            fileName: pending.fileName,
            totalBytes: pending.totalBytes,
            direction: TransferDirection.receive,
            peerIp: pending.senderIp,
            peerName: pending.senderIp,
            transferredBytes: received,
            state: TransferState.completed,
            localPath: destPath,
            startedAt: startedAt,
          ));
        } else {
          _emit(TransferTaskModel(
            id: transferId,
            fileName: pending.fileName,
            totalBytes: pending.totalBytes,
            direction: TransferDirection.receive,
            peerIp: pending.senderIp,
            peerName: pending.senderIp,
            transferredBytes: received,
            state: TransferState.paused,
            startedAt: startedAt,
          ));
        }
      },
      onError: (e) async {
        await sink.close();
        _openSinks.remove(transferId);
        _activeStreams.remove(transferId);
        _emit(TransferTaskModel(
          id: transferId,
          fileName: pending.fileName,
          totalBytes: pending.totalBytes,
          direction: TransferDirection.receive,
          peerIp: pending.senderIp,
          peerName: pending.senderIp,
          transferredBytes: received,
          state: TransferState.failed,
          errorMessage: e.toString(),
          startedAt: startedAt,
        ));
      },
      cancelOnError: true,
    );
  }

  Future<void> rejectIncoming(String transferId) async {
    final pending = _pendingSockets.remove(transferId);
    if (pending == null) return;
    pending.socket.add(FrameCodec.encodeJson({'status': 'rejected'}));
    pending.socket.destroy();
  }

  /// Sends [file] to [peerIp]. Automatically resumes from wherever the
  /// receiver reports it left off (its `.part` file length), so a retry
  /// after [cancelTransfer] or a dropped link does not restart from
  /// zero.
  Future<String> sendFile({
    required String peerIp,
    required File file,
    required String peerName,
  }) async {
    final transferId = _uuid.v4();
    final totalBytes = await file.length();
    final fileName = p.basename(file.path);
    final startedAt = DateTime.now();

    _emit(TransferTaskModel(
      id: transferId,
      fileName: fileName,
      totalBytes: totalBytes,
      direction: TransferDirection.send,
      peerIp: peerIp,
      peerName: peerName,
      state: TransferState.connecting,
      startedAt: startedAt,
    ));

    try {
      final socket = await Socket.connect(peerIp, AppConstants.transferPort,
          timeout: const Duration(seconds: 10));

      socket.add(FrameCodec.encodeJson({
        'transferId': transferId,
        'fileName': fileName,
        'totalBytes': totalBytes,
      }));

      final responseFrame =
          await socket.cast<List<int>>().transform(FrameDecoder()).first;
      final response =
          jsonDecode(utf8.decode(responseFrame)) as Map<String, dynamic>;

      if (response['status'] != 'ready') {
        _emit(TransferTaskModel(
          id: transferId,
          fileName: fileName,
          totalBytes: totalBytes,
          direction: TransferDirection.send,
          peerIp: peerIp,
          peerName: peerName,
          state: TransferState.failed,
          errorMessage: 'Rejected by peer',
          startedAt: startedAt,
        ));
        socket.destroy();
        return transferId;
      }

      final offset = response['resumeOffset'] as int? ?? 0;
      final reader = await file.open(mode: FileMode.read);
      _openReaders[transferId] = reader;
      await reader.setPosition(offset);

      var sent = offset;
      var lastBytes = offset;
      var lastTime = DateTime.now();

      _emit(TransferTaskModel(
        id: transferId,
        fileName: fileName,
        totalBytes: totalBytes,
        direction: TransferDirection.send,
        peerIp: peerIp,
        peerName: peerName,
        transferredBytes: sent,
        state: TransferState.transferring,
        startedAt: startedAt,
      ));

      final cancelToken = _CancelToken();
      _cancelTokens[transferId] = cancelToken;

      while (sent < totalBytes) {
        if (cancelToken.cancelled) {
          _emit(TransferTaskModel(
            id: transferId,
            fileName: fileName,
            totalBytes: totalBytes,
            direction: TransferDirection.send,
            peerIp: peerIp,
            peerName: peerName,
            transferredBytes: sent,
            state: TransferState.cancelled,
            startedAt: startedAt,
          ));
          break;
        }
        final remaining = totalBytes - sent;
        final toRead = remaining < AppConstants.chunkSize
            ? remaining
            : AppConstants.chunkSize;
        final bytes = await reader.read(toRead);
        socket.add(bytes);
        await socket.flush();
        sent += bytes.length;

        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds;
        if (elapsed >= 500 || sent >= totalBytes) {
          final speed =
              (sent - lastBytes) / (elapsed == 0 ? 1 : elapsed / 1000);
          lastBytes = sent;
          lastTime = now;
          _emit(TransferTaskModel(
            id: transferId,
            fileName: fileName,
            totalBytes: totalBytes,
            direction: TransferDirection.send,
            peerIp: peerIp,
            peerName: peerName,
            transferredBytes: sent,
            state: sent >= totalBytes
                ? TransferState.completed
                : TransferState.transferring,
            speedBytesPerSec: speed,
            startedAt: startedAt,
          ));
        }
      }

      await reader.close();
      _openReaders.remove(transferId);
      _cancelTokens.remove(transferId);
      await socket.close();
    } catch (e) {
      _logger.w('Send to $peerIp failed: $e');
      _emit(TransferTaskModel(
        id: transferId,
        fileName: fileName,
        totalBytes: totalBytes,
        direction: TransferDirection.send,
        peerIp: peerIp,
        peerName: peerName,
        state: TransferState.failed,
        errorMessage: e.toString(),
        startedAt: startedAt,
      ));
    }

    return transferId;
  }

  /// Cancels an in-flight send. Bytes already delivered remain on the
  /// receiver's `.part` file so a later [sendFile] call for the same
  /// file resumes instead of restarting from zero.
  void cancelTransfer(String transferId) {
    _cancelTokens[transferId]?.cancelled = true;
    _activeStreams[transferId]?.cancel();
  }

  void _emit(TransferTaskModel task) => _taskUpdateController.add(task);

  Future<void> dispose() async {
    for (final sink in _openSinks.values) {
      await sink.close();
    }
    for (final reader in _openReaders.values) {
      await reader.close();
    }
    for (final sub in _activeStreams.values) {
      await sub.cancel();
    }
    await _server?.close();
    await _incomingRequestController.close();
    await _taskUpdateController.close();
  }
}
