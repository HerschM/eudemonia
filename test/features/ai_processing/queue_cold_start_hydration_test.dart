import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
  @override
  bool isInitialized = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> initialize(String modelDir) async {
    isInitialized = true;
  }

  @override
  void dispose() {
    isInitialized = false;
  }

  @override
  Future<String> transcribe(String audioFilePath) async => 'Transcribed audio content';
}

class FakeLLMService implements LLMService {
  @override
  bool isInitialized = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> initialize(String modelPath) async {
    isInitialized = true;
  }

  @override
  void dispose() {
    isInitialized = false;
  }

  @override
  Future<void> clearKvCache({String reason = 'manual'}) async {}

  @override
  Future<LLMResponse> processText(String rawTranscript) async {
    return const LLMResponse(
      rawText: 'Transcribed audio content',
      correctedText: 'Transcribed audio content.',
      selectedFolder: 'Work',
      folderScores: {'Work': 0.9},
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
    tempDir = await Directory.systemTemp.createTemp('eudemonia_hydration_test_');
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

  group('TASK-031: Persistent Queue Hydration & Cold-Start State Recovery', () {
    test('1. Service initializes with pre-existing queue.json containing 3 items and sets pendingCount to 3', () async {
      // Pre-seed queue.json with 3 items
      final preSeeded = [
        {
          'id': 'item-1',
          'audioFilePath': '/path/to/1.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
        {
          'id': 'item-2',
          'audioFilePath': '/path/to/2.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
        {
          'id': 'item-3',
          'audioFilePath': '/path/to/3.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
      ];
      await queueStorageFile.writeAsString(jsonEncode(preSeeded), flush: true);

      int notifiedPending = 0;
      final queueService = AudioQueueService(
        fakeSTT,
        fakeLLM,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
        onQueueChanged: (pending, failed) {
          notifiedPending = pending;
        },
      );

      await queueService.loadFromStorage();

      expect(queueService.items.length, 3);
      expect(queueService.pendingCount, 3);
      expect(notifiedPending, 3);
      expect(queueService.items[0].id, 'item-1');
      expect(queueService.items[1].id, 'item-2');
      expect(queueService.items[2].id, 'item-3');
    });

    test('2. Worker resumes processing next pending item without losing queue sequence', () async {
      final preSeeded = [
        {
          'id': 'item-first',
          'audioFilePath': '/path/to/first.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
        {
          'id': 'item-second',
          'audioFilePath': '/path/to/second.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
      ];
      await queueStorageFile.writeAsString(jsonEncode(preSeeded), flush: true);

      final queueService = AudioQueueService(
        fakeSTT,
        fakeLLM,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
      );

      await queueService.loadFromStorage();
      expect(queueService.pendingCount, 2);

      // Process pending queue items
      await queueService.processPending();

      expect(queueService.pendingCount, 0);
      expect(fakeNotesRepo.savedNotes.length, 2);
      expect(fakeNotesRepo.savedNotes[0].originalAudioPath, '/path/to/first.wav');
      expect(fakeNotesRepo.savedNotes[1].originalAudioPath, '/path/to/second.wav');
    });

    test('3. Corrupt entries are quarantined without terminating hydration', () async {
      final mixedData = [
        {
          'id': 'valid-1',
          'audioFilePath': '/path/to/valid1.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
        'corrupt-string-entry', // not a map
        {
          'id': 'valid-2',
          'audioFilePath': '/path/to/valid2.wav',
          'recordedAt': DateTime.now().toIso8601String(),
          'status': 'pending',
        },
      ];
      await queueStorageFile.writeAsString(jsonEncode(mixedData), flush: true);

      final queueService = AudioQueueService(
        fakeSTT,
        fakeLLM,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
      );

      await queueService.loadFromStorage();

      // Only valid entries should be hydrated
      expect(queueService.items.length, 2);
      expect(queueService.items[0].id, 'valid-1');
      expect(queueService.items[1].id, 'valid-2');
      expect(queueService.pendingCount, 2);
    });
  });
}
