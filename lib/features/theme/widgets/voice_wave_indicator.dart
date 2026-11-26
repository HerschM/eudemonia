import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Animated voice waveform: [bars] rounded bars rising and falling out of phase with each
/// other, [height] tall at their peak. Used while listening (capture capsule) and while a
/// recording waits to be transcribed (thought card). Shows still bars when the system asks
/// for no animation. Pure presentational widget.
class VoiceWaveIndicator extends StatefulWidget {
  final double height;
  final Color? color;
  final int bars;

  const VoiceWaveIndicator({super.key, this.height = 20, this.color, this.bars = 7});

  @override
  State<VoiceWaveIndicator> createState() => _VoiceWaveIndicatorState();
}

class _VoiceWaveIndicatorState extends State<VoiceWaveIndicator> with SingleTickerProviderStateMixin {
  /// Shortest a bar gets, as a share of [VoiceWaveIndicator.height].
  static const _minFraction = 0.3;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _animate = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (_animate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
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
    final color = widget.color ?? AppColors.accentCapture;
    final peak = widget.height;
    final barWidth = math.max(2.0, peak * 0.15);
    return RepaintBoundary(
      child: SizedBox(
        height: peak,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.bars, (i) {
                final phase = (i / widget.bars) * math.pi;
                final level = _animate ? math.sin(_controller.value * math.pi + phase).abs() : 0.5;
                return Container(
                  key: Key('voice_wave_bar_$i'),
                  width: barWidth,
                  height: peak * (_minFraction + (1 - _minFraction) * level),
                  margin: EdgeInsets.symmetric(horizontal: barWidth / 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(barWidth / 2),
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
