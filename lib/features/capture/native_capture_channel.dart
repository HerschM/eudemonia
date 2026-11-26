import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether native code is recording, and since when (epoch milliseconds).
class NativeCaptureState {
  final bool isRecording;
  final int? startedAtMs;

  const NativeCaptureState({required this.isRecording, this.startedAtMs});

  static const NativeCaptureState idle = NativeCaptureState(isRecording: false);

  factory NativeCaptureState.fromMap(Object? map) {
    if (map is! Map) return idle;
    final recording = map['isRecording'] == true;
    final startedAt = map['startedAtMs'];
    return NativeCaptureState(
      isRecording: recording,
      startedAtMs: recording && startedAt is num ? startedAt.toInt() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NativeCaptureState &&
      other.isRecording == isRecording &&
      other.startedAtMs == startedAtMs;

  @override
  int get hashCode => Object.hash(isRecording, startedAtMs);

  @override
  String toString() => 'NativeCaptureState(isRecording: $isRecording, startedAtMs: $startedAtMs)';
}

/// A finished recording that native code has committed to its inbox.
class PendingCapture {
  final String path;
  final int startedAtMs;

  const PendingCapture({required this.path, required this.startedAtMs});

  /// Returns `null` for a malformed entry so one bad row cannot hide the others.
  static PendingCapture? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final startedAt = raw['startedAtMs'];
    if (path is! String || path.isEmpty || startedAt is! num) return null;
    return PendingCapture(path: path, startedAtMs: startedAt.toInt());
  }
}

typedef NativeStateListener = void Function(NativeCaptureState state);
typedef NativeCaptureSavedListener = void Function(PendingCapture capture);

/// Typed wrapper over the `com.eudemonia/capture` channel. Native code owns the microphone and
/// is the single source of truth for "is recording"; Dart only issues commands and listens.
///
/// A missing platform implementation (tests, non-Android hosts) behaves as idle / nothing
/// pending, never as an error, so callers need no platform guards.
class NativeCaptureChannel {
  static const MethodChannel _defaultChannel = MethodChannel('com.eudemonia/capture');

  final MethodChannel _channel;

  NativeCaptureChannel({MethodChannel? channel}) : _channel = channel ?? _defaultChannel;

  /// Starts delivering native events. Replaces any previous listener.
  void setListeners({
    required NativeStateListener onStateChanged,
    required NativeCaptureSavedListener onCaptureSaved,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onStateChanged':
          onStateChanged(NativeCaptureState.fromMap(call.arguments));
        case 'onCaptureSaved':
          final capture = PendingCapture.tryParse(call.arguments);
          if (capture != null) onCaptureSaved(capture);
      }
      return null;
    });
  }

  void clearListeners() => _channel.setMethodCallHandler(null);

  Future<NativeCaptureState> getState() => _stateCall('getState');

  /// The returned state has `isRecording == false` when native could not start (for example
  /// while the microphone permission is still being requested).
  Future<NativeCaptureState> start() => _stateCall('start');

  Future<NativeCaptureState> stop() => _stateCall('stop');

  /// Finished recordings waiting in the native inbox, oldest first.
  Future<List<PendingCapture>> listPendingCaptures() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listPendingCaptures');
      return [
        for (final entry in raw ?? const <Object?>[])
          ?PendingCapture.tryParse(entry),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Asks the launcher to pin the capture widget; `false` when pinning is unsupported.
  Future<bool> requestPinWidget() async {
    try {
      return await _channel.invokeMethod<bool>('requestPinWidget') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<NativeCaptureState> _stateCall(String method) async {
    try {
      return NativeCaptureState.fromMap(await _channel.invokeMethod<Object?>(method));
    } on MissingPluginException {
      return NativeCaptureState.idle;
    } on PlatformException {
      return NativeCaptureState.idle;
    }
  }
}

final nativeCaptureChannelProvider = Provider<NativeCaptureChannel>((ref) {
  return NativeCaptureChannel();
});
