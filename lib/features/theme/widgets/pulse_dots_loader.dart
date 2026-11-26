import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Loading indicator: three dots that pulse (scale and opacity) one after the other.
/// Replaces the round spinner. Shows still dots when the system asks for no animation.
/// Pure presentational widget.
class PulseDotsLoader extends StatefulWidget {
  final double dotSize;
  final Color? color;

  const PulseDotsLoader({super.key, this.dotSize = 6, this.color});

  @override
  State<PulseDotsLoader> createState() => _PulseDotsLoaderState();
}

class _PulseDotsLoaderState extends State<PulseDotsLoader> with SingleTickerProviderStateMixin {
  static const _dotCount = 3;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _animate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (_animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0..1 pulse of dot [index]: each dot peaks a little after the previous one.
  double _pulse(int index) {
    final phase = (_controller.value - index / (_dotCount + 1)) % 1.0;
    return phase < 0.5 ? math.sin(phase / 0.5 * math.pi) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final size = widget.dotSize;
    return RepaintBoundary(
      child: Semantics(
        label: 'Loading',
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dotCount, (i) {
                final pulse = _animate ? _pulse(i) : 1.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.35),
                  child: Opacity(
                    key: Key('pulse_dot_$i'),
                    opacity: _animate ? 0.3 + 0.7 * pulse : 0.7,
                    child: Transform.scale(
                      scale: _animate ? 0.6 + 0.4 * pulse : 1.0,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
