import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_recording_service.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';

/// Lightweight coordinator for user recording gestures.
///
/// Decouples audio capture from heavy AI inference:
/// - startRecording(): Starts audio capture with 0ms delay. Never loads heavy models during capture.
/// - stopRecordingAndProcess(): Stops capture, immediately enqueues the audio file to the persistent queue,
///   and returns in <5ms without blocking the UI.
class BatchPipelineService {
  final AudioRecordingService _audioService;
  final AudioQueueService _queueService;

  BatchPipelineService(
    this._audioService,
    this._queueService,
  );

  Future<void> startRecording() async {
    await _audioService.startRecording();
  }

  Future<void> stopRecordingAndProcess() async {
    final audioPath = await _audioService.stopRecording();

    if (audioPath != null) {
      await _queueService.enqueue(audioPath);
    }
  }
}

final batchPipelineProvider = Provider<BatchPipelineService>((ref) {
  final audioService = ref.watch(audioRecordingServiceProvider);
  final queueService = ref.watch(audioQueueServiceProvider);
  return BatchPipelineService(
    audioService,
    queueService,
  );
});
