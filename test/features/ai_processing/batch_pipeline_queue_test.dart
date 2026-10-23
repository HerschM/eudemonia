import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_recording_service.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/batch_pipeline_service.dart';

class FakeAudioRecordingService implements AudioRecordingService {
  bool isRecording = false;
  String? returnedPath = '/test/audio.m4a';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> startRecording() async {
    isRecording = true;
  }

  @override
  Future<String?> stopRecording() async {
    isRecording = false;
    return returnedPath;
  }
}

class MockAudioQueueService implements AudioQueueService {
  final List<String> enqueuedPaths = [];
  bool processPendingCalled = false;

  @override
  int get pendingCount => enqueuedPaths.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AudioQueueItem> enqueue(String audioFilePath, {bool autoProcess = true}) async {
    enqueuedPaths.add(audioFilePath);
    if (autoProcess) {
      processPendingCalled = true;
    }
    return AudioQueueItem(
      id: 'test_id',
      audioFilePath: audioFilePath,
      recordedAt: DateTime.now(),
    );
  }

  @override
  Future<void> processPending() async {
    processPendingCalled = true;
  }
}

void main() {
  late FakeAudioRecordingService fakeAudioService;
  late MockAudioQueueService mockQueueService;
  late BatchPipelineService pipelineService;

  setUp(() {
    fakeAudioService = FakeAudioRecordingService();
    mockQueueService = MockAudioQueueService();
    pipelineService = BatchPipelineService(
      fakeAudioService,
      mockQueueService,
    );
  });

  test('startRecording only begins audio recording without blocking for models', () async {
    await pipelineService.startRecording();
    expect(fakeAudioService.isRecording, isTrue);
  });

  test('stopRecordingAndProcess enqueues audio file into queue and triggers background worker without waiting', () async {
    fakeAudioService.returnedPath = '/recordings/my_thought.m4a';

    await pipelineService.stopRecordingAndProcess();

    expect(mockQueueService.enqueuedPaths, contains('/recordings/my_thought.m4a'));
    expect(mockQueueService.processPendingCalled, isTrue);
  });

  test('stopRecordingAndProcess with null path does not enqueue', () async {
    fakeAudioService.returnedPath = null;

    await pipelineService.stopRecordingAndProcess();

    expect(mockQueueService.enqueuedPaths, isEmpty);
  });
}
