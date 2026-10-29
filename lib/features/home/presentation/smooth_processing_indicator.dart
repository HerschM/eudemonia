import 'dart:math' as math;
import 'package:flutter/material.dart';

class SmoothProcessingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const SmoothProcessingIndicator({
    super.key,
    this.size = 16.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  State<SmoothProcessingIndicator> createState() => _SmoothProcessingIndicatorState();
}

class _SmoothProcessingIndicatorState extends State<SmoothProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              key: const Key('smooth_indicator_custom_paint'),
              size: Size(widget.size, widget.size),
              painter: _SmoothArcPainter(
                progress: _controller.value,
                color: effectiveColor,
                strokeWidth: widget.strokeWidth,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SmoothArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _SmoothArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (radius <= 0) return;

    // Track circle (faint background)
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, trackPaint);

    // Dynamic animated sweep arc
    final startAngle = progress * 2 * math.pi;
    final sweepAngle = math.pi * (0.6 + 0.4 * math.sin(progress * 2 * math.pi).abs());

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SmoothArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
