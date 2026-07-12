import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/chat_message_model.dart';

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

  @override
  void initState() {
    super.initState();
    _resolvePath();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
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
        Text('Voice message', style: TextStyle(color: widget.textColor)),
      ],
    );
  }
}
