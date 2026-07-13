import 'dart:math';

import 'package:flutter/material.dart';

class RadarSweep extends StatefulWidget {
  const RadarSweep({super.key, this.size = 160, this.active = true});

  final double size;
  final bool active;

  @override
  State<RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<RadarSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void didUpdateWidget(covariant RadarSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(
            progress: _controller.value,
            primary: scheme.primary,
            secondary: scheme.secondary,
            active: widget.active,
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.active,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = primary.withOpacity(0.18);
    for (final fraction in [0.35, 0.62, 0.88, 1.0]) {
      canvas.drawCircle(center, radius * fraction, ringPaint);
    }

    if (!active) return;

    final sweepAngle = progress * 2 * pi;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * pi,
      transform: GradientRotation(sweepAngle),
      colors: [
        secondary.withOpacity(0),
        secondary.withOpacity(0.55),
        primary.withOpacity(0),
      ],
      stops: const [0.0, 0.08, 0.32],
    );
    final sweepPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    final dotPaint = Paint()..color = primary;
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.active != active;
}
