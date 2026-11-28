import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// "The AI is thinking" indicator: a small spark that gently pulses, followed by [label] with a
/// soft band of light sweeping across it. One animation controller, repainted in its own layer.
/// Replaces the round spinner. Still (no pulse, no sweep) when the system asks for no animation
/// or when [animate] is false. Pure presentational widget.
class ThinkingIndicator extends StatefulWidget {
  final String label;
  final TextStyle? style;
  final Color? color;

  /// False draws the indicator without motion, e.g. for work that is queued but not running.
  final bool animate;

  const ThinkingIndicator({super.key, required this.label, this.style, this.color, this.animate = true});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator> with SingleTickerProviderStateMixin {
  static const _loop = Duration(milliseconds: 1600);

  late final AnimationController _controller = AnimationController(vsync: this, duration: _loop);
  bool _systemAllowsMotion = true;

  bool get _moving => widget.animate && _systemAllowsMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _systemAllowsMotion = !MediaQuery.disableAnimationsOf(context);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant ThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  void _syncController() {
    if (_moving) {
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

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accentAI;
    final style = (widget.style ?? const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))
        .copyWith(color: Colors.white);
    return RepaintBoundary(
      child: Semantics(
        label: widget.label,
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _moving ? _controller.value : 0.0;
            // One breath per loop: 0.85 .. 1.1 of the icon size, and a small sway.
            final breath = _moving ? math.sin(t * 2 * math.pi) : 0.0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: breath * 0.25,
                  child: Transform.scale(
                    scale: 0.975 + breath * 0.125,
                    child: Icon(Icons.hub_outlined, key: const Key('thinking_spark'), size: 13, color: color),
                  ),
                ),
                const SizedBox(width: 6),
                _moving ? _sweptLabel(style, color, t) : Text(widget.label, style: style.copyWith(color: color)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The label in [color], with a lighter band travelling from left to right.
  Widget _sweptLabel(TextStyle style, Color color, double t) {
    final highlight = Color.lerp(color, Colors.white, 0.75)!;
    return ShaderMask(
      key: const Key('thinking_sweep'),
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [color, color, highlight, color, color],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        // Sliding the gradient from one label width left to one right moves the band across, with a rest at both ends.
        transform: _SlideGradient(t),
      ).createShader(bounds),
      child: Text(widget.label, style: style),
    );
  }
}

/// Slides a gradient from fully left of the shaded box (at 0) to fully right of it (at 1).
class _SlideGradient extends GradientTransform {
  final double progress;

  const _SlideGradient(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0.0, 0.0);
}
