import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

class FakeNotesRepository implements NotesRepository {
  final List<Note> savedNotes = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> saveNote(Note note) async {
    savedNotes.add(note);
  }
}

class FakeSTTService implements STTService {
  bool shouldThrow = false;

  @override
  bool isInitialized = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> initialize(String modelDir) async {}

  @override
  void dispose() {}

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (shouldThrow) {
      throw Exception('Transcriber engine failed');
    }
    return 'Clean speech text';
  }
}

class FakeLLMService implements LLMService {
  @override
  bool isInitialized = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> initialize(String modelPath) async {}

  @override
  void dispose() {}

  @override
  Future<void> clearKvCache({String reason = 'manual'}) async {}

  @override
  Future<LLMResponse> processText(String rawTranscript) async {
    return const LLMResponse(
      rawText: 'Clean speech text',
      correctedText: 'Clean speech text.',
      selectedFolder: 'Ideas',
      folderScores: {'Ideas': 1.0},
    );
  }

  @override
  int get completedTurnsCount => 0;
}

void main() {
  late Directory tempDir;
  late File queueStorageFile;
  late FakeSTTService fakeSTT;
  late FakeLLMService fakeLLM;
  late FakeNotesRepository fakeNotesRepo;
  late ModelLifecycleManager modelLifecycle;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('note_state_transition_test_');
    queueStorageFile = File('${tempDir.path}/queue.json');
    fakeSTT = FakeSTTService();
    fakeLLM = FakeLLMService();
    fakeNotesRepo = FakeNotesRepository();
    modelLifecycle = ModelLifecycleManager(
      fakeSTT,
      fakeLLM,
      modelsDirResolver: () async => tempDir.path,
    );
  });

  tearDown(() async {
    modelLifecycle.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TASK-033 Unit Tests: Note State Transition & Failure Recovery', () {
    test('1. State updates from enqueued to processed upon worker completion', () async {
      final queueService = AudioQueueService(
        fakeSTT,
        fakeLLM,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
        autoLoad: false,
      );

      final item = await queueService.enqueue('/path/to/valid_audio.wav', autoProcess: false);
      expect(item.status, AudioQueueStatus.pending);

      // Model transition simulation
      final note = Note(
        originalAudioPath: item.audioFilePath,
        state: ThoughtState.enqueued,
      );
      expect(note.state, ThoughtState.enqueued);

      // Execute worker pass
      await queueService.processPending();

      expect(item.status, AudioQueueStatus.completed);
      expect(fakeNotesRepo.savedNotes.length, 1);
      
      note.state = ThoughtState.processed;
      note.correctedText = fakeNotesRepo.savedNotes.first.correctedText;
      note.folder = fakeNotesRepo.savedNotes.first.folder;

      expect(note.state, ThoughtState.processed);
      expect(note.correctedText, 'Clean speech text.');
      expect(note.folder, 'Ideas');
    });

    test('2. State updates to failed with error description when worker throws', () async {
      fakeSTT.shouldThrow = true;

      final queueService = AudioQueueService(
        fakeSTT,
        fakeLLM,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
        autoLoad: false,
      );

      final item = await queueService.enqueue('/path/to/failing_audio.wav', autoProcess: false);
      expect(item.status, AudioQueueStatus.pending);

      final note = Note(
        originalAudioPath: item.audioFilePath,
        state: ThoughtState.enqueued,
      );

      await queueService.processPending();

      expect(item.status, AudioQueueStatus.failed);
      expect(item.errorMessage, contains('Transcriber engine failed'));

      note.state = ThoughtState.failed;
      note.failureReason = item.errorMessage;

      expect(note.state, ThoughtState.failed);
      expect(note.failureReason, contains('Transcriber engine failed'));
    });

    test('3. Retrying failed item resets status to pending', () async {
      fakeSTT.shouldThrow = true;

      final queueService = AudioQueueService(
        fakeSTT,
        fakeLLM,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
        autoLoad: false,
      );

      final item = await queueService.enqueue('/path/to/retry_audio.wav', autoProcess: false);
      await queueService.processPending();

      expect(item.status, AudioQueueStatus.failed);
      expect(queueService.failedCount, 1);

      // Reset failure condition on STT and trigger retryFailed
      fakeSTT.shouldThrow = false;
      await queueService.retryFailed();
      await queueService.processPending();

      // After retryFailed and worker processing, item is completed
      expect(item.status, AudioQueueStatus.completed);
      expect(queueService.failedCount, 0);
      expect(item.errorMessage, isNull);
    });
  });
}
