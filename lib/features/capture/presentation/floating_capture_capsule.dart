import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Floating in-app capture trigger (FR9.3).
///
/// Idle: `[ 🎙️ / Press Vol Up + Down to Capture ]`. While recording it morphs
/// into a listening waveform with an elapsed timer. Pure presentational widget.
class FloatingCaptureCapsule extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const FloatingCaptureCapsule({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  @override
  State<FloatingCaptureCapsule> createState() => _FloatingCaptureCapsuleState();
}

class _FloatingCaptureCapsuleState extends State<FloatingCaptureCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveform;
  final Stopwatch _elapsed = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _waveform = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.isRecording) _startListening();
  }

  @override
  void didUpdateWidget(covariant FloatingCaptureCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _startListening();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopListening();
    }
  }

  void _startListening() {
    _elapsed
      ..reset()
      ..start();
    _waveform.repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopListening() {
    _ticker?.cancel();
    _ticker = null;
    _elapsed.stop();
    _waveform.stop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _waveform.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final seconds = _elapsed.elapsed.inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = widget.isRecording;
    return Material(
      color: isRecording ? const Color(0xFF0F291E) : const Color(0xFF1F1F27),
      elevation: isRecording ? 8 : 6,
      shadowColor: isRecording
          ? AppColors.accentCapture.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.pillRadius),
        side: BorderSide(
          color: isRecording
              ? AppColors.accentCapture
              : AppColors.accentCapture.withValues(alpha: 0.45),
          width: isRecording ? 1.5 : 1.2,
        ),
      ),
      child: InkWell(
        key: Key(isRecording ? 'floating_capture_button_active' : 'floating_capture_button'),
        borderRadius: BorderRadius.circular(AppColors.pillRadius),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: isRecording ? _buildListening() : _buildIdle(),
          ),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mic, color: AppColors.accentCapture, size: 22),
        SizedBox(width: 8),
        Text(
          '/',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 16,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'Press Vol Up + Down to Capture',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildListening() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.stop_circle, color: AppColors.accentCapture, size: 22),
        const SizedBox(width: 10),
        AnimatedBuilder(
          animation: _waveform,
          builder: (context, _) {
            const barCount = 7;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(barCount, (i) {
                final phase = (i / barCount) * math.pi;
                final height = 6.0 + 14.0 * math.sin(_waveform.value * math.pi + phase).abs();
                return Container(
                  width: 3,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.accentCapture,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          '$_elapsedLabel • Tap to Stop',
          key: const Key('capture_elapsed_label'),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.accentCapture,
          ),
        ),
      ],
    );
  }
}
