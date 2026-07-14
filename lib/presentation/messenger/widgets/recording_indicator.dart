import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../../data/services/voice_recorder_service.dart';
import 'waveform_bars.dart';

class RecordingIndicator extends StatefulWidget {
  const RecordingIndicator({super.key, required this.recorder, required this.isPaused});

  final VoiceRecorderService recorder;
  final bool isPaused;

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator> {
  static const _maxBars = 40;
  final List<double> _levels = List.filled(_maxBars, 0.08);
  StreamSubscription<Amplitude>? _sub;
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sub = widget.recorder.amplitudeStream().listen(_onAmplitude);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!widget.isPaused && mounted) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  void _onAmplitude(Amplitude amplitude) {
    if (widget.isPaused || !mounted) return;
    final normalized = ((amplitude.current + 45) / 45).clamp(0.05, 1.0);
    setState(() {
      _levels.removeAt(0);
      _levels.add(normalized);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  String get _durationLabel {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.fiber_manual_record,
            size: 14, color: widget.isPaused ? scheme.onSurface.withOpacity(0.4) : scheme.error),
        const SizedBox(width: 8),
        Text(_durationLabel, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: WaveformBars(
              levels: _levels,
              color: scheme.primary.withOpacity(0.3),
              activeColor: scheme.primary,
              progress: 1,
              height: 24,
            ),
          ),
        ),
      ],
    );
  }
}
