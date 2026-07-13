import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Records short voice messages to a local AAC file, ready to be handed
/// to [FileTransferService.sendFile] like any other attachment. Voice
/// notes deliberately go through the same file-transfer + confirmation
/// path as any other file rather than a separate raw-audio-streaming
/// protocol, keeping exactly one security-reviewed path for bytes
/// landing on a peer's disk.
class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final _uuid = const Uuid();
  String? _currentPath;
  DateTime? _startedAt;

  bool get isRecording => _currentPath != null;
  bool _paused = false;
  bool get isPaused => _paused;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> pause() async {
    if (!isRecording || _paused) return;
    await _recorder.pause();
    _paused = true;
  }

  Future<void> resume() async {
    if (!isRecording || !_paused) return;
    await _recorder.resume();
    _paused = false;
  }

  /// Live input level, updated every [interval]. Values are raw dBFS
  /// (typically -45..0 for voice); the waveform widget normalizes them.
  Stream<Amplitude> amplitudeStream({Duration interval = const Duration(milliseconds: 100)}) {
    return _recorder.onAmplitudeChanged(interval);
  }

  /// Starts recording to a fresh temp file. Throws a [StateError] if a
  /// recording is already in progress.
  Future<void> start() async {
    if (isRecording) {
      throw StateError('A voice recording is already in progress');
    }
    if (!await hasPermission()) {
      throw StateError('Microphone permission was not granted');
    }
    final dir = await getTemporaryDirectory();
    final fileName = 'voice_${_uuid.v4()}.m4a';
    final path = p.join(dir.path, fileName);

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
      path: path,
    );
    _currentPath = path;
    _startedAt = DateTime.now();
    _paused = false;
  }

  /// Stops the current recording and returns the resulting file, or
  /// `null` if nothing was recording. Recordings under 500ms are
  /// discarded and deleted as accidental taps.
  Future<File?> stop() async {
    if (!isRecording) return null;
    final path = await _recorder.stop();
    final startedAt = _startedAt;
    _currentPath = null;
    _startedAt = null;
    _paused = false;

    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;

    final duration = startedAt != null ? DateTime.now().difference(startedAt) : null;
    if (duration != null && duration.inMilliseconds < 500) {
      await file.delete();
      return null;
    }
    return file;
  }

  Future<void> cancel() async {
    if (!isRecording) return;
    final path = await _recorder.stop();
    _currentPath = null;
    _startedAt = null;
    _paused = false;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> dispose() async {
    if (isRecording) await cancel();
    await _recorder.dispose();
  }
}
