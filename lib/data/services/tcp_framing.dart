import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../core/constants/app_constants.dart';

/// Encodes and reassembles length-prefixed TCP frames.
///
/// Every frame on the wire is `[4-byte big-endian length][payload]`.
/// This solves TCP's packet fragmentation/coalescing at the source: a
/// frame is only ever delivered to the application once every one of
/// its bytes has arrived, regardless of how the OS split it into
/// segments.
class FrameCodec {
  FrameCodec._();

  /// Wraps [payload] with its 4-byte length prefix.
  static Uint8List encode(List<int> payload) {
    if (payload.length > AppConstants.maxFrameLength) {
      throw ArgumentError('Frame exceeds maxFrameLength');
    }
    final header = ByteData(4)..setUint32(0, payload.length, Endian.big);
    return Uint8List(4 + payload.length)
      ..setRange(0, 4, header.buffer.asUint8List())
      ..setRange(4, 4 + payload.length, payload);
  }

  /// Convenience helper for UTF-8/JSON text frames.
  static Uint8List encodeJson(Map<String, dynamic> json) =>
      encode(utf8.encode(jsonEncode(json)));
}

/// A [StreamTransformer] that turns a raw byte stream (as delivered by a
/// [Socket]) into a stream of fully-reassembled frame payloads.
///
/// Handles both fragmentation (a frame split across multiple TCP
/// segments) and coalescing (multiple frames arriving in one chunk) by
/// keeping an internal growable buffer.
class FrameDecoder extends StreamTransformerBase<List<int>, Uint8List> {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  int? _expectedLength;

  @override
  Stream<Uint8List> bind(Stream<List<int>> stream) {
    late StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () {
        stream.listen(
          (chunk) {
            _buffer.add(chunk);
            _drain(controller);
          },
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: false,
        );
      },
    );
    return controller.stream;
  }

  void _drain(StreamController<Uint8List> controller) {
    while (true) {
      final bytes = _buffer.toBytes();

      if (_expectedLength == null) {
        if (bytes.length < 4) return;
        final view = ByteData.sublistView(bytes, 0, 4);
        _expectedLength = view.getUint32(0, Endian.big);
        if (_expectedLength! > AppConstants.maxFrameLength) {
          controller.addError(StateError('Frame too large'));
          _expectedLength = null;
          _buffer.clear();
          return;
        }
        _buffer.clear();
        _buffer.add(bytes.sublist(4));
        continue;
      }

      final remaining = _buffer.toBytes();
      if (remaining.length < _expectedLength!) return;

      final framePayload = remaining.sublist(0, _expectedLength!);
      final rest = remaining.sublist(_expectedLength!);
      _buffer.clear();
      _buffer.add(rest);
      _expectedLength = null;
      controller.add(Uint8List.fromList(framePayload));
    }
  }
}
