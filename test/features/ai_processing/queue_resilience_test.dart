import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

class FakeSTTService implements STTService {
  @override
  bool isInitialized = false;
  int initializeCalls = 0;
  int disposeCalls = 0;
  String transcript = 'A thought';
  Completer<void>? gate;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> initialize(String modelDir) async {
    initializeCalls++;
    isInitialized = true;
  }

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!isInitialized) throw StateError('STT Service not initialized');
    if (gate != null) await gate!.future;
    if (audioFilePath.contains('corrupt')) throw Exception('Unreadable audio');
    return transcript;
  }

  @override
  void dispose() {
    disposeCalls++;
    isInitialized = false;
  }
}

class FakeLLMService implements LLMService {
  @override
  bool isInitialized = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  int get completedTurnsCount => 0;

  @override
  Future<void> initialize(String modelPath) async {
    isInitialized = true;
  }

  @override
  Future<LLMResponse> processText(String rawTranscript) async {
    if (!isInitialized) throw StateError('LLM Service not initialized');
    return LLMResponse(
      rawText: rawTranscript,
      correctedText: '$rawTranscript.',
      selectedFolder: 'Ideas',
      folderScores: const {'Ideas': 0.9},
    );
  }

  @override
  void dispose() {
    isInitialized = false;
  }
}

void main() {
  late Directory tempDir;
  late File queueFile;
  late FakeSTTService stt;
  late FakeLLMService llm;
  late NotesRepository notesRepo;
  late ModelLifecycleManager lifecycle;

  AudioQueueService buildService({ModelLifecycleManager? manager}) => AudioQueueService(
        stt,
        llm,
        notesRepo,
        manager ?? lifecycle,
        storageFileResolver: () async => queueFile,
      );

  Map<String, dynamic> seed(String id, String status, {int? seq}) => {
        'id': id,
        'audioFilePath': '/path/to/$id.wav',
        'recordedAt': DateTime.now().toIso8601String(),
        'status': status,
        'sequenceNumber': seq,
      };

  List<dynamic> readQueueFile() => jsonDecode(queueFile.readAsStringSync()) as List<dynamic>;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('queue_resilience_test_');
    queueFile = File('${tempDir.path}/queue.json');
    stt = FakeSTTService();
    llm = FakeLLMService();
    notesRepo = NotesRepository();
    lifecycle = ModelLifecycleManager(stt, llm, modelsDirResolver: () async => tempDir.path);
  });

  tearDown(() async {
    lifecycle.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Cold-start recovery', () {
    test('items interrupted mid-inference are handed back to the worker as pending', () async {
      await queueFile.writeAsString(jsonEncode([
        seed('a', 'transcribing'),
        seed('b', 'categorizing'),
        seed('c', 'pending'),
        seed('d', 'failed'),
      ]));

      final service = buildService();
      await service.loadFromStorage();

      expect(service.items.map((i) => i.status), [
        AudioQueueStatus.pending,
        AudioQueueStatus.pending,
        AudioQueueStatus.pending,
        AudioQueueStatus.failed,
      ]);
      expect(readQueueFile().map((j) => j['status']), ['pending', 'pending', 'pending', 'failed']);
    });

    test('completed items are pruned so the queue file cannot grow without bound', () async {
      await queueFile.writeAsString(jsonEncode([
        seed('done-1', 'completed'),
        seed('done-2', 'completed'),
        seed('todo', 'pending'),
      ]));

      final service = buildService();
      await service.loadFromStorage();

      expect(service.items.map((i) => i.id), ['todo']);
      expect(readQueueFile().map((j) => j['id']), ['todo']);
    });

    test('a capture enqueued before hydration settles does not drop persisted items', () async {
      await queueFile.writeAsString(jsonEncode([seed('old-1', 'pending'), seed('old-2', 'failed')]));

      // Constructor starts hydration; enqueue races it without awaiting loadFromStorage().
      final service = buildService();
      await service.enqueue('/path/to/new.wav', autoProcess: false);

      expect(service.items.map((i) => i.audioFilePath),
          ['/path/to/old-1.wav', '/path/to/old-2.wav', '/path/to/new.wav']);
      expect(readQueueFile().length, 3);
    });

    test('resumePendingWork hydrates and drains the leftover queue', () async {
      await queueFile.writeAsString(jsonEncode([seed('a', 'transcribing', seq: 1), seed('b', 'pending', seq: 2)]));

      final service = buildService();
      await service.resumePendingWork();

      expect(service.pendingCount, 0);
      final notes = await notesRepo.getAllNotes();
      expect(notes.map((n) => n.originalAudioPath).toSet(), {'/path/to/a.wav', '/path/to/b.wav'});
    });
  });

  group('Persistence integrity', () {
    test('rapid successive mutations always leave a parseable queue file', () async {
      final service = buildService();
      await Future.wait([
        for (int i = 0; i < 12; i++) service.enqueue('/path/to/$i.wav', autoProcess: false),
      ]);
      await service.removeItemByAudioPath('/path/to/3.wav');

      final persisted = readQueueFile();
      expect(persisted.length, 11);
      expect(File('${queueFile.path}.tmp').existsSync(), isFalse);
    });
  });

  group('Daily sequence numbering (FR9.4 / FR9.5)', () {
    test('continues from the highest sequence already persisted today', () async {
      await notesRepo.saveNote(Note(correctedText: 'earlier', dailySequenceNumber: 7));

      final service = buildService();
      final item = await service.enqueue('/path/to/x.wav', autoProcess: false);

      expect(item.sequenceNumber, 8);
    });

    test('deleting the newest thought leaves a gap instead of reissuing its number', () async {
      final service = buildService();
      await service.enqueue('/path/to/1.wav', autoProcess: false);
      await service.enqueue('/path/to/2.wav', autoProcess: false);
      final third = await service.enqueue('/path/to/3.wav', autoProcess: false);
      expect(third.sequenceNumber, 3);

      await service.removeItemByAudioPath('/path/to/3.wav');
      final fourth = await service.enqueue('/path/to/4.wav', autoProcess: false);

      expect(fourth.sequenceNumber, 4);
    });
  });

  group('Worker failure handling', () {
    test('a thought deleted mid-inference is not resurrected as a note', () async {
      final service = buildService();
      stt.gate = Completer<void>();

      await service.enqueue('/path/to/doomed.wav', autoProcess: false);
      final processing = service.processPending();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await service.removeItemByAudioPath('/path/to/doomed.wav');
      stt.gate!.complete();
      await processing;

      expect(await notesRepo.getAllNotes(), isEmpty);
      expect(service.items, isEmpty);
      expect(service.failedCount, 0);
    });

    test('models are still evicted after the TTL when every item fails', () async {
      final shortTtl = ModelLifecycleManager(
        stt,
        llm,
        config: const LLMConfig(modelInactivityTtl: Duration(milliseconds: 60)),
        modelsDirResolver: () async => tempDir.path,
      );
      addTearDown(shortTtl.dispose);
      final service = buildService(manager: shortTtl);

      await service.enqueue('/path/to/corrupt.wav', autoProcess: false);
      await service.processPending();

      expect(service.failedCount, 1);
      expect(shortTtl.state, ModelLifecycleState.ready);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(shortTtl.state, ModelLifecycleState.unloaded);
      expect(stt.isInitialized, isFalse);
      expect(llm.isInitialized, isFalse);
    });

    test('a failing item does not block the items behind it', () async {
      final service = buildService();
      await service.enqueue('/path/to/corrupt.wav', autoProcess: false);
      await service.enqueue('/path/to/good.wav', autoProcess: false);

      await service.processPending();

      expect(service.items.map((i) => i.status), [AudioQueueStatus.failed, AudioQueueStatus.completed]);
      expect((await notesRepo.getAllNotes()).single.originalAudioPath, '/path/to/good.wav');
    });
  });
}
