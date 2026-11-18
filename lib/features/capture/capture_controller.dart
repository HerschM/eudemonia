import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/batch_pipeline_service.dart';

/// Owns the recording toggle driven by native capture triggers (dual volume
/// press, lock screen notification action). State is `true` while recording.
///
/// Lives outside the widget tree so triggers are handled no matter which
/// screen is mounted.
class CaptureController extends Notifier<bool> {
  static const MethodChannel hardwareChannel = MethodChannel('com.eudemonia/hardware_buttons');
  static const Duration triggerCooldown = Duration(milliseconds: 500);

  final MethodChannel _channel;
  DateTime? _lastTriggerTime;
  bool _isToggling = false;

  CaptureController({this._channel = hardwareChannel});

  @override
  bool build() {
    _channel.setMethodCallHandler(_handleMethodCall);
    return false;
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onHardwareTrigger') return;
    final args = call.arguments;
    final bool isLocked = args is Map ? (args['isLocked'] as bool? ?? false) : false;
    final bool? desiredRecording = args is Map ? args['desiredRecording'] as bool? : null;
    await handleTrigger(isLocked: isLocked, desiredRecording: desiredRecording);
  }

  /// Toggles recording. When [desiredRecording] is set (explicit start/stop
  /// actions), a trigger that already matches the current state is a no-op.
  ///
  /// Returns the queued capture when this trigger finished a recording.
  Future<AudioQueueItem?> handleTrigger({bool isLocked = false, bool? desiredRecording}) async {
    final logger = ref.read(appLoggerProvider);

    if (desiredRecording != null && desiredRecording == state) {
      await _syncNativeRecordingState();
      return null;
    }

    final now = DateTime.now();
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!) < triggerCooldown) {
      logger.warning('[Capture] Trigger dropped by debounce (<500ms)');
      await _syncNativeRecordingState();
      return null;
    }
    if (_isToggling) {
      logger.warning('[Capture] Trigger dropped: already toggling');
      return null;
    }

    _lastTriggerTime = now;
    _isToggling = true;
    AudioQueueItem? captured;

    try {
      logger.trigger('Hardware Trigger Received. isLocked: $isLocked, current isRecording: $state');
      final pipeline = ref.read(batchPipelineProvider);

      if (!state) {
        // Flip first so the listening indicator appears without waiting on the recorder.
        state = true;
        final started = await pipeline.startRecording();
        if (!started) {
          state = false;
          logger.warning('[Capture] Recording did not start; capture state reverted.');
        }
      } else {
        state = false;
        captured = await pipeline.stopRecordingAndProcess();
      }
    } catch (e, stack) {
      state = false;
      logger.error('[Capture] Error during hardware trigger handling', error: e, stackTrace: stack);
    } finally {
      _isToggling = false;
      await _syncNativeRecordingState();
    }
    return captured;
  }

  /// Reports the authoritative state to native code, which mirrors it in the
  /// lock screen notification and the start/stop haptic pattern.
  Future<void> _syncNativeRecordingState() async {
    try {
      await _channel.invokeMethod('setRecordingState', {'isRecording': state});
    } catch (_) {
      // No platform implementation (tests, non-Android hosts).
    }
  }
}

final captureControllerProvider = NotifierProvider<CaptureController, bool>(() {
  return CaptureController();
});
