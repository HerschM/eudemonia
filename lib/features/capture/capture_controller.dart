import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';

/// Mirrors the native recorder: state is `true` while native code is recording.
///
/// Native code owns the microphone and fires every start/stop (capsule, notification, widget);
/// this notifier only follows its events, issues the capsule's start/stop commands and hands
/// finished recordings to the [CaptureInboxIngestor]. It lives outside the widget tree so
/// events are handled no matter which screen is mounted.
class CaptureController extends Notifier<bool> {
  /// How long a stop waits for native to commit the recording before giving up on a result.
  static const Duration saveTimeout = Duration(seconds: 5);

  DateTime? _startedAt;
  Duration? _maxDuration;
  bool _isToggling = false;
  bool _warmupRequested = false;
  Completer<AudioQueueItem?>? _saveWaiter;

  Future<void> _startupSync = Future.value();

  /// Completes once the startup state sync and inbox scan have finished.
  Future<void> get startupSync => _startupSync;

  /// When the current recording began (native clock), or `null` while idle.
  DateTime? get startedAt => state ? _startedAt : null;

  /// The longest a recording may run before native stops and saves it, or `null` until native
  /// has reported it. Native reports it with every state, so it is known while idle too.
  Duration? get maxDuration => _maxDuration;

  @override
  bool build() {
    final channel = ref.read(nativeCaptureChannelProvider);
    channel.setListeners(
      onStateChanged: _applyNativeState,
      onCaptureSaved: _onCaptureSaved,
    );
    ref.onDispose(() {
      channel.clearListeners();
      _completeWaiter(null);
    });
    _startupSync = _syncAtStartup(channel);
    return false;
  }

  Future<void> _syncAtStartup(NativeCaptureChannel channel) async {
    final logger = ref.read(appLoggerProvider);
    try {
      _applyNativeState(await channel.getState());
      if (!ref.mounted) return;
      await ref.read(captureInboxIngestorProvider).ingestPending();
    } catch (e, stack) {
      logger.error('[Capture] Startup sync failed', error: e, stackTrace: stack);
    }
  }

  void _applyNativeState(NativeCaptureState native) {
    if (!ref.mounted) return;
    final maxDurationMs = native.maxDurationMs;
    // A state without a limit (for example the idle fallback after an error) keeps the last one.
    if (maxDurationMs != null) _maxDuration = Duration(milliseconds: maxDurationMs);
    if (native.isRecording) {
      _startedAt = native.startedAtMs == null
          ? (_startedAt ?? DateTime.now())
          : DateTime.fromMillisecondsSinceEpoch(native.startedAtMs!);
      state = true;
      // Load the speech model while the user is still speaking, so the first thought is not
      // held up by a cold load after the recording ends. Fire-and-forget: never awaited here.
      if (!_warmupRequested) {
        _warmupRequested = true;
        ref.read(modelLifecycleManagerProvider).warmupOnRecordingStart();
      }
    } else {
      _startedAt = null;
      _warmupRequested = false;
      state = false;
    }
  }

  Future<void> _onCaptureSaved(PendingCapture capture) async {
    if (!ref.mounted) return;
    final item = await ref
        .read(captureInboxIngestorProvider)
        .ingest(capture.path, capture.startedAtMs);
    _completeWaiter(item);
  }

  void _completeWaiter(AudioQueueItem? item) {
    final waiter = _saveWaiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete(item);
    _saveWaiter = null;
  }

  /// Toggles recording from the in-app capsule. When [desiredRecording] is set, a request that
  /// already matches the current state is a no-op.
  ///
  /// Returns the queued capture when this call finished a recording.
  Future<AudioQueueItem?> handleTrigger({bool? desiredRecording}) async {
    final logger = ref.read(appLoggerProvider);
    if (desiredRecording != null && desiredRecording == state) return null;
    if (_isToggling) {
      logger.warning('[Capture] Trigger dropped: already toggling');
      return null;
    }

    _isToggling = true;
    Future<AudioQueueItem?>? saved;
    Completer<AudioQueueItem?>? waiterOfThisStop;
    try {
      final channel = ref.read(nativeCaptureChannelProvider);
      if (!state) {
        // Flip first so the listening indicator appears without waiting on native code.
        _startedAt = DateTime.now();
        state = true;
        final started = await channel.start();
        _applyNativeState(started);
        if (!started.isRecording) {
          logger.warning('[Capture] Recording did not start; capture state reverted.');
        }
      } else {
        // The waiter exists before `stop` is sent, so a fast `onCaptureSaved` cannot be missed.
        final waiter = waiterOfThisStop = _saveWaiter = Completer<AudioQueueItem?>();
        state = false;
        _startedAt = null;
        _warmupRequested = false;
        _applyNativeState(await channel.stop());
        saved = waiter.future;
      }
    } catch (e, stack) {
      logger.error('[Capture] Error during capture trigger handling', error: e, stackTrace: stack);
      _applyNativeState(NativeCaptureState.idle);
      _completeWaiter(null);
    } finally {
      _isToggling = false;
    }
    if (saved == null) return null;

    return saved.timeout(saveTimeout, onTimeout: () {
      logger.warning('[Capture] No saved recording reported within ${saveTimeout.inSeconds}s of stop.');
      if (identical(_saveWaiter, waiterOfThisStop)) _saveWaiter = null;
      return null;
    });
  }
}

final captureControllerProvider = NotifierProvider<CaptureController, bool>(() {
  return CaptureController();
});
