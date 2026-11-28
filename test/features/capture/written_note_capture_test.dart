import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/capture/written_note_capture.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

class _IdleRunner implements SynthesisRunner {
  @override
  Future<SynthesisRunResult> run({required bool manual}) async => SynthesisRunResult.nothingToDo;

  @override
  bool get isRunning => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeQueueItems extends QueueItemsNotifier {
  final List<AudioQueueItem> initial;
  _FakeQueueItems(this.initial);
  @override
  List<AudioQueueItem> build() => initial;
}

void main() {
  late NotesRepository repo;
  late int savedSignals;

  WrittenNoteCapture capture({DateTime? now, Future<int> Function(DateTime)? next}) => WrittenNoteCapture(
        notes: repo,
        nextSequenceNumber: next ?? (day) async => (await repo.maxDailySequenceFor(day)) + 1,
        onSaved: () => savedSignals++,
        now: () => now ?? DateTime.now(),
      );

  setUp(() {
    repo = NotesRepository();
    savedSignals = 0;
  });

  group('WrittenNoteCapture.save', () {
    test('stores a processed, read, written thought with the text as both raw and corrected text', () async {
      final at = DateTime(2026, 11, 28, 9, 30);
      final note = await capture(now: at).save('  Buy a lamp for the desk.  ');

      expect(note, isNotNull);
      final stored = (await repo.getAllNotes()).single;
      expect(stored.originalAudioPath, isNull);
      expect(stored.rawText, 'Buy a lamp for the desk.');
      expect(stored.correctedText, 'Buy a lamp for the desk.');
      expect(stored.state, ThoughtState.processed);
      expect(stored.isRead, isTrue);
      expect(stored.isWritten, isTrue);
      expect(stored.createdAt, at);
      expect(stored.dailySequenceNumber, 1);
      expect(stored.failureReason, isNull);
      expect(savedSignals, 1, reason: 'the synthesis trigger is told a thought was saved');
    });

    test('refuses empty or blank text and stores nothing', () async {
      expect(await capture().save(''), isNull);
      expect(await capture().save('  \n\t '), isNull);

      expect(await repo.getAllNotes(), isEmpty);
      expect(savedSignals, 0);
    });

    test('takes the next number after a voice thought of the same day, and none is reused', () async {
      final at = DateTime(2026, 11, 28, 9, 30);
      await repo.saveNote(Note(correctedText: 'Spoken.', createdAt: at, dailySequenceNumber: 4, originalAudioPath: '/a.wav'));

      final first = await capture(now: at.add(const Duration(minutes: 5))).save('First written.');
      final second = await capture(now: at.add(const Duration(minutes: 6))).save('Second written.');

      expect(first!.dailySequenceNumber, 5);
      expect(second!.dailySequenceNumber, 6);
    });

    test('numbers a new day from 1', () async {
      await repo.saveNote(Note(correctedText: 'Yesterday.', createdAt: DateTime(2026, 11, 27, 22), dailySequenceNumber: 9));

      final note = await capture(now: DateTime(2026, 11, 28, 8)).save('Today.');

      expect(note!.dailySequenceNumber, 1);
    });

    test('uses the number source it is given (the one voice thoughts use)', () async {
      final note = await capture(next: (_) async => 42).save('Numbered elsewhere.');

      expect(note!.dailySequenceNumber, 42);
    });

    test('a written thought is ready for Synthesis exactly like a transcribed one', () async {
      final container = ProviderContainer(overrides: [notesRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      await repo.saveNote(Note(correctedText: 'Spoken.', originalAudioPath: '/a.wav'));
      await capture().save('Typed.');

      final stored = await repo.getAllNotes();
      expect(stored.every((n) => isSynthesisCandidate(n, manual: false, maxAttempts: 1)), isTrue);
      expect(await container.read(rawNotesReadyToClusterCountProvider.future), 2);
    });
  });

  group('writtenNoteCaptureProvider', () {
    test('tells the automatic trigger, which counts the written thought as waiting', () async {
      final timers = <Duration>[];
      final trigger = SynthesisTriggerController(
        runner: _IdleRunner(),
        eligibleCount: () async =>
            (await repo.getAllNotes()).where((n) => isSynthesisCandidate(n, manual: false, maxAttempts: 1)).length,
        settings: () => const SynthesisSettings(noteThreshold: 1),
        createTimer: (duration, callback) {
          timers.add(duration);
          return Timer(const Duration(days: 1), callback);
        },
      );
      final container = ProviderContainer(overrides: [
        notesRepositoryProvider.overrideWithValue(repo),
        queueItemsProvider.overrideWith(() => _FakeQueueItems(const [])),
        synthesisTriggerControllerProvider.overrideWithValue(trigger),
      ]);
      addTearDown(() {
        trigger.dispose();
        container.dispose();
      });

      await container.read(writtenNoteCaptureProvider).save('Typed once.');
      await pumpEventQueue();

      expect(timers, contains(SynthesisTriggerController.settleDelay), reason: 'threshold of 1 reached by the written note');
    });

    test('takes its number from the queue\'s counter, so the next recording never repeats it', () async {
      final at = DateTime.now();
      final dir = Directory.systemTemp.createTempSync('written_note_seq');
      addTearDown(() => dir.deleteSync(recursive: true));
      final stt = STTService();
      final queue = AudioQueueService(
        stt,
        repo,
        ModelLifecycleManager(stt),
        storageFileResolver: () async => File('${dir.path}/queue.json'),
      );
      final container = ProviderContainer(overrides: [
        notesRepositoryProvider.overrideWithValue(repo),
        audioQueueServiceProvider.overrideWithValue(queue),
        synthesisTriggerControllerProvider.overrideWithValue(SynthesisTriggerController(
          runner: _IdleRunner(),
          eligibleCount: () async => 0,
          settings: () => const SynthesisSettings(),
        )),
      ]);
      addTearDown(container.dispose);
      await repo.saveNote(Note(correctedText: 'Spoken.', createdAt: at, dailySequenceNumber: 2));
      final waiting = await queue.enqueue('/q.wav', autoProcess: false, recordedAt: at);
      expect(waiting.sequenceNumber, 3);

      final note = await container.read(writtenNoteCaptureProvider).save('Typed while one waits.');
      expect(note!.dailySequenceNumber, 4, reason: 'after the stored #02 and the queued #03');

      final next = await queue.enqueue('/r.wav', autoProcess: false, recordedAt: at);
      expect(next.sequenceNumber, 5, reason: 'the written note\'s #04 is taken');
    });
  });
}
