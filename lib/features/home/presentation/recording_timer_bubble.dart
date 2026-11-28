import 'dart:async';

import 'package:flutter/material.dart';
import 'package:eudemonia/core/formatting/recording_timer.dart';
import 'package:eudemonia/features/home/presentation/glass_bubble.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/voice_wave_indicator.dart';

/// The middle bubble while a recording runs: a recording dot, the voice wave and the elapsed time
/// (`00:07`, or `00:07 / 05:00` when a length limit is known), counted from [startedAt] so a
/// recording started from the notification or the home-screen widget shows the right time.
/// It is only built while recording; search is not available then.
class RecordingTimerBubble extends StatefulWidget {
  /// When the recording began; the moment the bubble appears when null.
  final DateTime? startedAt;

  /// The recording length limit, shown after the elapsed time; null shows elapsed time only.
  final Duration? maxDuration;

  const RecordingTimerBubble({super.key, this.startedAt, this.maxDuration});

  @override
  State<RecordingTimerBubble> createState() => _RecordingTimerBubbleState();
}

class _RecordingTimerBubbleState extends State<RecordingTimerBubble> {
  late DateTime _since = widget.startedAt ?? DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RecordingTimerBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startedAt != oldWidget.startedAt) _since = widget.startedAt ?? _since;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = formatRecordingTimer(DateTime.now().difference(_since), widget.maxDuration);
    return GlassBubble(
      label: 'Recording $text',
      borderColor: AppColors.accentCapture.withValues(alpha: 0.45),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('recording_dot'),
            width: 9,
            height: 9,
            decoration: const BoxDecoration(color: AppColors.accentCapture, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          // The moving wave the record capsule always showed while listening.
          const VoiceWaveIndicator(),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                key: const Key('recording_timer_text'),
                style: const TextStyle(
                  color: AppColors.accentCapture,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
