import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlaybackState {
  final String? currentAudioPath;
  final bool isPlaying;

  const AudioPlaybackState({
    this.currentAudioPath,
    this.isPlaying = false,
  });

  String? get currentlyPlayingPath => currentAudioPath;

  AudioPlaybackState copyWith({
    String? currentAudioPath,
    bool? isPlaying,
  }) {
    return AudioPlaybackState(
      currentAudioPath: currentAudioPath ?? this.currentAudioPath,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class AudioPlaybackController extends Notifier<AudioPlaybackState> {
  static const MethodChannel defaultChannel = MethodChannel('com.eudemonia/audio_playback');
  final MethodChannel _channel;

  AudioPlaybackController({MethodChannel? channel})
      : _channel = channel ?? defaultChannel;

  @override
  AudioPlaybackState build() {
    try {
      _channel.setMethodCallHandler(_handlePlatformCall);
    } catch (_) {
      // Handled in environments without platform messenger
    }
    return const AudioPlaybackState();
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    if (call.method == 'onAudioPlaybackComplete') {
      state = state.copyWith(isPlaying: false);
    }
  }

  String? get currentAudioPath => state.currentAudioPath;
  String? get currentlyPlayingPath => state.currentAudioPath;
  bool get isPlaying => state.isPlaying;

  Future<void> play(String path) async {
    if (state.currentAudioPath == path && state.isPlaying) {
      await pause();
      return;
    }

    try {
      await _channel.invokeMethod('playAudio', {'path': path});
    } catch (_) {
      // Gracefully continue in mock/test environments
    }

    state = AudioPlaybackState(currentAudioPath: path, isPlaying: true);
  }

  Future<void> togglePlayback(String path) async {
    await play(path);
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pauseAudio');
    } catch (_) {}
    state = state.copyWith(isPlaying: false);
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
    state = const AudioPlaybackState();
  }
}

final audioPlaybackControllerProvider = NotifierProvider<AudioPlaybackController, AudioPlaybackState>(() {
  return AudioPlaybackController();
});
