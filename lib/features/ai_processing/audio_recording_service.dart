import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

class AudioRecordingService {
  final _audioRecorder = AudioRecorder();
  final AppLogger? _logger;
  String? _currentFilePath;

  AudioRecordingService({this._logger});

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final requested = await Permission.microphone.request();
    return requested.isGranted;
  }

  Future<void> startRecording() async {
    try {
      if (await checkPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        _currentFilePath = '${dir.path}/$fileName';

        // Record to WAV format for STT compatibility
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: _currentFilePath!,
        );
        _logger?.info('[AudioRecordingService] Started recording to $_currentFilePath');
      } else {
        _logger?.warning('[AudioRecordingService] Microphone permission not granted');
      }
    } catch (e, stack) {
      _logger?.error('[AudioRecordingService] Error starting recording', error: e, stackTrace: stack);
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _logger?.info('[AudioRecordingService] Stopped recording. Output: $path');
      return path;
    } catch (e, stack) {
      _logger?.error('[AudioRecordingService] Error stopping recording', error: e, stackTrace: stack);
      return null;
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return AudioRecordingService(logger: logger);
});
