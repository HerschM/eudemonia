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

  @override
  Future<List<Note>> getRecentNotes({int limit = 50}) async => savedNotes;
}

class FakeSTTService implements STTService {
  String stubTranscript = 'Hello world thought';
  bool wasCalled = false;
  @override
  bool isInitialized = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isModelLoaded => isInitialized;

  @override
  Future<void> initialize(String modelDirPath) async {
    isInitialized = true;
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!isInitialized) {
      throw Exception('STT Service not initialized');
    }
    wasCalled = true;
    return stubTranscript;
  }

  @override
  void dispose() {
    isInitialized = false;
  }
}

class FakeLLMService implements LLMService {
  LLMResponse stubResponse = const LLMResponse(
    rawText: 'Hello world thought',
    correctedText: 'Hello world thought.',
    selectedFolder: 'Ideas',
    folderScores: {'Ideas': 0.95},
  );
  int processTextCallCount = 0;
  @override
  bool isInitialized = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  int get completedTurnsCount => processTextCallCount;

  @override
  Future<void> initialize(String modelPath) async {
    isInitialized = true;
  }

  @override
  Future<LLMResponse> processText(String rawTranscript) async {
    if (!isInitialized) {
      throw Exception('LLM Service not initialized');
    }
    processTextCallCount++;
    return stubResponse;
  }

  @override
  void dispose() {
    isInitialized = false;
  }
}

void main() {
  late Directory tempDir;
  late File queueStorageFile;
  late FakeSTTService fakeSTT;
  late FakeLLMService fakeLLM;
  late FakeNotesRepository fakeNotesRepo;
  late ModelLifecycleManager modelLifecycle;
  late AudioQueueService queueService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('queue_test_');
    queueStorageFile = File('${tempDir.path}/queue.json');
    fakeSTT = FakeSTTService();
    fakeLLM = FakeLLMService();
    fakeNotesRepo = FakeNotesRepository();
    modelLifecycle = ModelLifecycleManager(
      fakeSTT,
      fakeLLM,
      modelsDirResolver: () async => tempDir.path,
    );

    queueService = AudioQueueService(
      fakeSTT,
      fakeLLM,
      fakeNotesRepo,
      modelLifecycle,
      storageFileResolver: () async => queueStorageFile,
    );
  });

  tearDown(() async {
    queueService.dispose();
    modelLifecycle.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AudioQueueService starts empty with pendingCount = 0', () async {
    expect(queueService.pendingCount, 0);
    expect(queueService.items, isEmpty);
  });

  test('enqueue adds multiple items and accumulates pendingCount', () async {
    await queueService.enqueue('/path/to/thought1.m4a', autoProcess: false);
    await queueService.enqueue('/path/to/thought2.m4a', autoProcess: false);
    await queueService.enqueue('/path/to/thought3.m4a', autoProcess: false);

    expect(queueService.pendingCount, 3);
    expect(queueService.items.length, 3);
    expect(await queueStorageFile.exists(), isTrue);
  });

  test('processQueue initializes models via ModelLifecycleManager and completes all items', () async {
    expect(fakeSTT.isInitialized, isFalse);
    expect(fakeLLM.isInitialized, isFalse);

    await queueService.enqueue('/path/to/audio1.m4a', autoProcess: false);
    await queueService.enqueue('/path/to/audio2.m4a', autoProcess: false);
    expect(queueService.pendingCount, 2);

    await queueService.processPending();

    // Verify models were initialized by queue worker
    expect(fakeSTT.isInitialized, isTrue);
    expect(fakeLLM.isInitialized, isTrue);
    expect(fakeSTT.wasCalled, isTrue);
    expect(fakeLLM.processTextCallCount, 2);
    expect(fakeNotesRepo.savedNotes.length, 2);
    expect(queueService.pendingCount, 0);
    expect(queueService.items.every((i) => i.status == AudioQueueStatus.completed), isTrue);
  });

  test('failed item due to empty speech transitions to failed status and does not block queue', () async {
    final failingSTT = FakeSTTService();
    failingSTT.stubTranscript = ''; // Empty transcription
    final customLifecycle = ModelLifecycleManager(
      failingSTT,
      fakeLLM,
      modelsDirResolver: () async => tempDir.path,
    );

    final service = AudioQueueService(
      failingSTT,
      fakeLLM,
      fakeNotesRepo,
      customLifecycle,
      storageFileResolver: () async => queueStorageFile,
    );

    await service.enqueue('/path/to/empty.m4a', autoProcess: false);
    await service.processPending();

    expect(service.items.first.status, AudioQueueStatus.failed);
    expect(service.pendingCount, 0);
    service.dispose();
    customLifecycle.dispose();
  });
}
