import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/cpu_wake_lock.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
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

  Future<List<Note>> getRecentNotes({int limit = 50}) async => savedNotes;
}

class FakeSTTService implements STTService {
  String stubTranscript = 'Hello world thought';
  bool wasCalled = false;

  /// Runs while an item is being transcribed.
  void Function()? onTranscribe;
  @override
  bool isInitialized = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    onTranscribe?.call();
    return stubTranscript;
  }

  @override
  void dispose() {
    isInitialized = false;
  }
}

/// Logs to a shared event list so the order of holds, transcriptions and releases is observable.
class FakeCpuWakeLock implements CpuWakeLock {
  final List<String> events;
  final List<Duration> holds = [];

  FakeCpuWakeLock(this.events);

  @override
  Future<void> hold(Duration timeout) async {
    holds.add(timeout);
    events.add('hold');
  }

  @override
  Future<void> release() async {
    events.add('release');
  }
}

class LoggingSTTService extends FakeSTTService {
  final List<String> events;
  bool failNext = false;

  LoggingSTTService(this.events);

  @override
  Future<String> transcribe(String audioFilePath) async {
    events.add('transcribe');
    if (failNext || audioFilePath.contains('corrupt')) throw Exception('Unreadable audio');
    return super.transcribe(audioFilePath);
  }
}

/// Returns silence for a path containing `silent`, throws for one containing `corrupt`.
class _ScriptedSTTService extends FakeSTTService {
  bool failCorrupt = true;

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (failCorrupt && audioFilePath.contains('corrupt')) {
      throw Exception('Unreadable audio');
    }
    stubTranscript = audioFilePath.contains('silent') ? '' : 'Hello world thought';
    return super.transcribe(audioFilePath);
  }
}

void main() {
  late Directory tempDir;
  late File queueStorageFile;
  late FakeSTTService fakeSTT;
  late FakeNotesRepository fakeNotesRepo;
  late ModelLifecycleManager modelLifecycle;
  late AudioQueueService queueService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('queue_test_');
    queueStorageFile = File('${tempDir.path}/queue.json');
    fakeSTT = FakeSTTService();
    fakeNotesRepo = FakeNotesRepository();
    modelLifecycle = ModelLifecycleManager(
      fakeSTT,
      modelsDirResolver: () async => tempDir.path,
    );

    queueService = AudioQueueService(
      fakeSTT,
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

    await queueService.enqueue('/path/to/audio1.m4a', autoProcess: false);
    await queueService.enqueue('/path/to/audio2.m4a', autoProcess: false);
    expect(queueService.pendingCount, 2);

    await queueService.processPending();

    // Verify models were initialized by queue worker
    expect(fakeSTT.isInitialized, isTrue);
    expect(fakeSTT.wasCalled, isTrue);
    expect(fakeNotesRepo.savedNotes.length, 2);
    expect(queueService.pendingCount, 0);
    expect(queueService.items.every((i) => i.status == AudioQueueStatus.completed), isTrue);
  });

  test('a processed item is saved exactly as transcribed, fillers kept, in Uncategorized', () async {
    fakeSTT.stubTranscript = '  So um I think we should, um, ship it  ';
    final seen = <AudioQueueStatus>{};
    final service = AudioQueueService(
      fakeSTT,
      fakeNotesRepo,
      modelLifecycle,
      storageFileResolver: () async => queueStorageFile,
      onItemsChanged: (items) => seen.addAll(items.map((i) => i.status)),
    );

    await service.enqueue('/path/to/um.m4a', autoProcess: false);
    await service.processPending();

    final note = fakeNotesRepo.savedNotes.single;
    expect(note.rawText, '  So um I think we should, um, ship it  ');
    expect(note.correctedText, 'So um I think we should, um, ship it');
    expect(note.correctedText, note.rawText.trim());
    expect(service.items.single.correctedText, note.correctedText);
    expect(seen, contains(AudioQueueStatus.transcribing));
    service.dispose();
  });

  test('failed item due to empty speech transitions to failed status and does not block queue', () async {
    final failingSTT = FakeSTTService();
    failingSTT.stubTranscript = ''; // Empty transcription
    final customLifecycle = ModelLifecycleManager(
      failingSTT,
      modelsDirResolver: () async => tempDir.path,
    );

    final service = AudioQueueService(
      failingSTT,
      fakeNotesRepo,
      customLifecycle,
      storageFileResolver: () async => queueStorageFile,
    );

    await service.enqueue('/path/to/empty.m4a', autoProcess: false);
    await service.processPending();

    expect(service.items.first.status, AudioQueueStatus.failed);
    expect(service.items.first.errorMessage, silentRecordingMessage);
    expect(service.items.first.isSilent, isTrue);
    expect(service.pendingCount, 0);
    service.dispose();
    customLifecycle.dispose();
  });

  test('a silent recording is not counted as failed and is left alone by Retry; a real failure is and is retried',
      () async {
    final stt = _ScriptedSTTService();
    final lifecycle = ModelLifecycleManager(stt, modelsDirResolver: () async => tempDir.path);
    final reported = <(int, int)>[];
    final service = AudioQueueService(
      stt,
      fakeNotesRepo,
      lifecycle,
      storageFileResolver: () async => queueStorageFile,
      onQueueChanged: (pending, failed) => reported.add((pending, failed)),
    );

    await service.enqueue('/path/to/silent.m4a', autoProcess: false);
    await service.processPending();
    expect(service.items.single.status, AudioQueueStatus.failed, reason: 'parked as failed internally');
    expect(service.failedCount, 0, reason: 'a silent recording is not a failure for the user');
    expect(reported.last.$2, 0);

    await service.enqueue('/path/to/corrupt.m4a', autoProcess: false);
    await service.processPending();
    expect(service.failedCount, 1);
    expect(reported.last.$2, 1);

    // Retry re-queues the real failure only; the silent recording stays as it is.
    stt.failCorrupt = false;
    await service.retryFailed();
    await service.processPending();
    final byPath = {for (final i in service.items) i.audioFilePath: i};
    expect(byPath['/path/to/silent.m4a']!.status, AudioQueueStatus.failed);
    expect(byPath['/path/to/silent.m4a']!.errorMessage, silentRecordingMessage);
    expect(byPath['/path/to/corrupt.m4a']!.status, AudioQueueStatus.completed);
    expect(service.failedCount, 0);

    service.dispose();
    lifecycle.dispose();
  });

  test('isSilentRecordingMessage recognises the current and the older wording only', () {
    expect(isSilentRecordingMessage(silentRecordingMessage), isTrue);
    expect(isSilentRecordingMessage('No speech detected in audio recording.'), isTrue);
    expect(isSilentRecordingMessage('Speech recognition engine timeout after 30s.'), isFalse);
    expect(isSilentRecordingMessage(null), isFalse);
  });

  group('speech model not downloaded (FR16.2)', () {
    late bool speechReady;
    late AudioQueueService service;

    setUp(() {
      speechReady = false;
      service = AudioQueueService(
        fakeSTT,
        fakeNotesRepo,
        modelLifecycle,
        storageFileResolver: () async => queueStorageFile,
        isSpeechModelReady: () => speechReady,
      );
    });

    tearDown(() => service.dispose());

    test('items stay pending, untouched and never failed, while the model is missing', () async {
      await service.enqueue('/path/to/a.m4a');
      await service.enqueue('/path/to/b.m4a', autoProcess: false);

      await service.processPending();

      expect(service.items.map((i) => i.status), [AudioQueueStatus.pending, AudioQueueStatus.pending]);
      expect(service.items.every((i) => i.errorMessage == null), isTrue);
      expect(service.pendingCount, 2);
      expect(fakeSTT.isInitialized, isFalse, reason: 'no model load was attempted');
      expect(fakeNotesRepo.savedNotes, isEmpty);
    });

    test('the same items are transcribed once the model is ready', () async {
      await service.enqueue('/path/to/a.m4a', autoProcess: false);
      await service.enqueue('/path/to/b.m4a', autoProcess: false);
      await service.processPending();
      expect(service.pendingCount, 2);

      speechReady = true;
      await service.processPending();

      expect(service.pendingCount, 0);
      expect(fakeNotesRepo.savedNotes, hasLength(2));
      expect(service.items.every((i) => i.status == AudioQueueStatus.completed), isTrue);
    });

    test('a model deleted mid-drain stops the worker without failing what is left', () async {
      speechReady = true;
      fakeSTT.onTranscribe = () => speechReady = false;
      await service.enqueue('/path/to/a.m4a', autoProcess: false);
      await service.enqueue('/path/to/b.m4a', autoProcess: false);

      await service.processPending();

      expect(service.items.map((i) => i.status), [AudioQueueStatus.completed, AudioQueueStatus.pending]);
    });
  });

  group('CPU wake lock', () {
    late List<String> events;
    late FakeCpuWakeLock wakeLock;
    late LoggingSTTService stt;
    late ModelLifecycleManager lifecycle;
    late AudioQueueService service;

    setUp(() {
      events = [];
      wakeLock = FakeCpuWakeLock(events);
      stt = LoggingSTTService(events);
      lifecycle = ModelLifecycleManager(stt, modelsDirResolver: () async => tempDir.path);
      service = AudioQueueService(
        stt,
        fakeNotesRepo,
        lifecycle,
        wakeLock: wakeLock,
        storageFileResolver: () async => queueStorageFile,
      );
    });

    tearDown(() {
      service.dispose();
      lifecycle.dispose();
    });

    test('holds the CPU before each item and releases once when the queue is drained', () async {
      await service.enqueue('/path/to/a.m4a', autoProcess: false);
      await service.enqueue('/path/to/b.m4a', autoProcess: false);

      await service.processPending();

      expect(events, ['hold', 'transcribe', 'hold', 'transcribe', 'release']);
      expect(wakeLock.holds, [AudioQueueService.wakeLockWindow, AudioQueueService.wakeLockWindow]);
      expect(AudioQueueService.wakeLockWindow, const Duration(minutes: 5));
    });

    test('still releases when an item fails, and the remaining items are processed', () async {
      await service.enqueue('/path/to/corrupt.m4a', autoProcess: false);
      await service.enqueue('/path/to/good.m4a', autoProcess: false);

      await service.processPending();

      expect(events, ['hold', 'transcribe', 'hold', 'transcribe', 'release']);
      expect(service.items.first.status, AudioQueueStatus.failed);
      expect(service.items.last.status, AudioQueueStatus.completed);
    });

    test('releases when the only item fails', () async {
      stt.failNext = true;
      await service.enqueue('/path/to/a.m4a', autoProcess: false);

      await service.processPending();

      expect(events, ['hold', 'transcribe', 'release']);
      expect(service.items.single.status, AudioQueueStatus.failed);
    });

    test('an empty queue never touches the wake lock', () async {
      await service.processPending();

      expect(events, isEmpty);
    });

    test('a second drain holds and releases again', () async {
      await service.enqueue('/path/to/a.m4a', autoProcess: false);
      await service.processPending();
      await service.enqueue('/path/to/b.m4a', autoProcess: false);
      await service.processPending();

      expect(events, ['hold', 'transcribe', 'release', 'hold', 'transcribe', 'release']);
    });
  });
}
