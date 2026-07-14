import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/chat_message_model.dart';
import 'waveform_bars.dart';

/// Renders a play/pause control for a voice message bubble.
///
/// Outgoing voice messages already carry [ChatMessageModel.filePath]
/// (the sender's own temp recording). Incoming voice messages only
/// carry a [ChatMessageModel.fileName] — the audio bytes arrive
/// separately through the confirmation-gated file-transfer channel, so
/// this widget resolves the expected path in the shared received-files
/// folder and shows a "waiting to receive" state until that transfer
/// has actually been accepted and completed.
class VoiceMessageContent extends StatefulWidget {
  const VoiceMessageContent({super.key, required this.message, required this.textColor});

  final ChatMessageModel message;
  final Color textColor;

  @override
  State<VoiceMessageContent> createState() => _VoiceMessageContentState();
}

class _VoiceMessageContentState extends State<VoiceMessageContent> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  String? _resolvedPath;
  bool _resolving = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final List<double> _levels = _generateLevels(widget.message.id);

  static List<double> _generateLevels(String seed) {
    final random = Random(seed.hashCode);
    return List.generate(32, (_) => 0.15 + random.nextDouble() * 0.85);
  }

  @override
  void initState() {
    super.initState();
    _resolvePath();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  Future<void> _resolvePath() async {
    if (widget.message.filePath != null) {
      setState(() {
        _resolvedPath = widget.message.filePath;
        _resolving = false;
      });
      return;
    }
    final fileName = widget.message.fileName;
    if (fileName == null) {
      setState(() => _resolving = false);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final candidate = '${dir.path}/${AppConstants.receivedFilesDirName}/$fileName';
    final exists = await File(candidate).exists();
    if (!mounted) return;
    setState(() {
      _resolvedPath = exists ? candidate : null;
      _resolving = false;
    });
  }

  Future<void> _toggle() async {
    final path = _resolvedPath;
    if (path == null) return;
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(path));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return SizedBox(
        height: 32,
        width: 32,
        child: Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: widget.textColor),
          ),
        ),
      );
    }

    if (_resolvedPath == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 18, color: widget.textColor.withOpacity(0.8)),
          const SizedBox(width: 8),
          Text('Voice message — accept the file transfer to listen',
              style: TextStyle(color: widget.textColor.withOpacity(0.8), fontSize: 12)),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _state == PlayerState.playing ? 'Pause voice message' : 'Play voice message',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            _state == PlayerState.playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: widget.textColor,
            size: 30,
          ),
          onPressed: _toggle,
        ),
        const SizedBox(width: 8),
        WaveformBars(
          levels: _levels,
          color: widget.textColor.withOpacity(0.35),
          activeColor: widget.textColor,
          progress: _duration.inMilliseconds == 0
              ? 0
              : _position.inMilliseconds / _duration.inMilliseconds,
          height: 26,
          barWidth: 2.5,
        ),
        const SizedBox(width: 8),
        Text(_formatDuration(_duration - _position), style: TextStyle(color: widget.textColor, fontSize: 11)),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes.toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
