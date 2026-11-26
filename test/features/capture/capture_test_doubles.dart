import 'dart:async';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';

/// In-memory stand-in for the native recorder. Like the real channel it only works once the
/// controller has registered its listeners, so use before initialisation throws.
class FakeNativeCaptureChannel implements NativeCaptureChannel {
  NativeStateListener? _onStateChanged;
  NativeCaptureSavedListener? _onCaptureSaved;

  NativeCaptureState state = NativeCaptureState.idle;
  List<PendingCapture> pending = [];
  bool pinSucceeds = true;
  bool startSucceeds = true;

  /// When set, `stop` makes the "native" side report this saved recording, as the real one does.
  PendingCapture? saveOnStop;

  int startCalls = 0;
  int stopCalls = 0;
  int pinCalls = 0;
  Completer<void>? startGate;

  bool get hasListeners => _onStateChanged != null;

  void _requireInitialised() {
    if (!hasListeners) throw StateError('NativeCaptureChannel used before listeners were set');
  }

  @override
  void setListeners({
    required NativeStateListener onStateChanged,
    required NativeCaptureSavedListener onCaptureSaved,
  }) {
    _onStateChanged = onStateChanged;
    _onCaptureSaved = onCaptureSaved;
  }

  @override
  void clearListeners() {
    _onStateChanged = null;
    _onCaptureSaved = null;
  }

  /// A native-side change (capsule, notification or widget) pushed to Dart.
  void emitState(NativeCaptureState next) {
    _requireInitialised();
    state = next;
    _onStateChanged!(next);
  }

  void emitSaved(PendingCapture capture) {
    _requireInitialised();
    _onCaptureSaved!(capture);
  }

  @override
  Future<NativeCaptureState> getState() async {
    _requireInitialised();
    return state;
  }

  @override
  Future<NativeCaptureState> start() async {
    _requireInitialised();
    startCalls++;
    await startGate?.future;
    if (state.isRecording) throw StateError('start called while native is already recording');
    state = startSucceeds
        ? NativeCaptureState(isRecording: true, startedAtMs: DateTime.now().millisecondsSinceEpoch)
        : NativeCaptureState.idle;
    return state;
  }

  @override
  Future<NativeCaptureState> stop() async {
    _requireInitialised();
    stopCalls++;
    if (!state.isRecording) throw StateError('stop called while native is idle');
    state = NativeCaptureState.idle;
    final saved = saveOnStop;
    if (saved != null) scheduleMicrotask(() => emitSaved(saved));
    return state;
  }

  @override
  Future<List<PendingCapture>> listPendingCaptures() async {
    _requireInitialised();
    return List.of(pending);
  }

  @override
  Future<bool> requestPinWidget() async {
    pinCalls++;
    return pinSucceeds;
  }
}

/// Records what the controller hands to the ingestor.
class FakeCaptureInboxIngestor implements CaptureInboxIngestor {
  final List<(String, int)> ingested = [];
  int ingestPendingCalls = 0;
  int sequence = 0;

  @override
  Future<AudioQueueItem?> ingest(String path, int startedAtMs) async {
    ingested.add((path, startedAtMs));
    return AudioQueueItem(
      id: 'item-${++sequence}',
      audioFilePath: path,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
      sequenceNumber: sequence,
    );
  }

  @override
  Future<void> ingestPending() async {
    ingestPendingCalls++;
  }
}

class RecordingModelLifecycleManager extends ModelLifecycleManager {
  int warmupCalls = 0;

  RecordingModelLifecycleManager() : super(STTService());

  @override
  void warmupOnRecordingStart() => warmupCalls++;
}
