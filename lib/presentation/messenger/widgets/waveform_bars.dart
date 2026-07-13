import 'package:flutter/material.dart';

class WaveformBars extends StatelessWidget {
  const WaveformBars({
    super.key,
    required this.levels,
    required this.color,
    this.activeColor,
    this.progress = 0,
    this.height = 32,
    this.barWidth = 3,
    this.gap = 2,
  });

  final List<double> levels;
  final Color color;
  final Color? activeColor;
  final double progress;
  final double height;
  final double barWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: levels.length * (barWidth + gap),
        child: CustomPaint(
          painter: _WaveformPainter(
            levels: levels,
            color: color,
            activeColor: activeColor ?? color,
            progress: progress,
            barWidth: barWidth,
            gap: gap,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.color,
    required this.activeColor,
    required this.progress,
    required this.barWidth,
    required this.gap,
  });

  final List<double> levels;
  final Color color;
  final Color activeColor;
  final double progress;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final activeCount = (levels.length * progress).round();

    for (var i = 0; i < levels.length; i++) {
      final level = levels[i].clamp(0.08, 1.0);
      final barHeight = size.height * level;
      final dx = i * (barWidth + gap);
      final rect = Rect.fromLTWH(dx, (size.height - barHeight) / 2, barWidth, barHeight);
      final paint = Paint()..color = i < activeCount ? activeColor : color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.levels != levels ||
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor;
}
