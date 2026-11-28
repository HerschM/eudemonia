import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/recording_retention.dart';
import 'package:eudemonia/features/capture/recording_retention_settings.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

class _InMemoryRetentionStore implements RecordingRetentionStore {
  RecordingRetention? stored;
  int saves = 0;
  _InMemoryRetentionStore([this.stored]);

  @override
  Future<RecordingRetention?> load() async => stored;

  @override
  Future<void> save(RecordingRetention value) async {
    saves++;
    stored = value;
  }
}

void main() {
  group('RecordingRetention setting', () {
    test('has the four choices, Always first and the default, with their lengths', () {
      expect(RecordingRetention.values, [
        RecordingRetention.always,
        RecordingRetention.days90,
        RecordingRetention.days30,
        RecordingRetention.days7,
      ]);
      expect(RecordingRetention.always.days, isNull);
      expect(RecordingRetention.days90.days, 90);
      expect(RecordingRetention.days30.days, 30);
      expect(RecordingRetention.days7.days, 7);
      expect(RecordingRetention.always.label, 'Always');
      expect(RecordingRetention.days90.label, '90 days');
      expect(RecordingRetention.days30.label, '30 days');
      expect(RecordingRetention.days7.label, '7 days');
      expect(RecordingRetention.days30.keySuffix, '30');
      expect(RecordingRetention.always.keySuffix, 'always');
    });

    test('is Always until something is stored, loads a stored choice and stores a change', () async {
      final empty = ProviderContainer(overrides: [
        recordingRetentionStoreProvider.overrideWithValue(_InMemoryRetentionStore()),
      ]);
      addTearDown(empty.dispose);
      await empty.read(recordingRetentionProvider.notifier).ready;
      expect(empty.read(recordingRetentionProvider), RecordingRetention.always);

      final stored = _InMemoryRetentionStore(RecordingRetention.days30);
      final container = ProviderContainer(overrides: [recordingRetentionStoreProvider.overrideWithValue(stored)]);
      addTearDown(container.dispose);
      await container.read(recordingRetentionProvider.notifier).ready;
      expect(container.read(recordingRetentionProvider), RecordingRetention.days30);

      container.read(recordingRetentionProvider.notifier).set(RecordingRetention.days7);
      expect(container.read(recordingRetentionProvider), RecordingRetention.days7, reason: 'synchronous');
      await Future<void>.delayed(Duration.zero);
      expect(stored.stored, RecordingRetention.days7);
    });

    test('a choice made before the stored one has loaded is not overwritten by it', () async {
      final stored = _InMemoryRetentionStore(RecordingRetention.days90);
      final container = ProviderContainer(overrides: [recordingRetentionStoreProvider.overrideWithValue(stored)]);
      addTearDown(container.dispose);
      final notifier = container.read(recordingRetentionProvider.notifier);
      notifier.set(RecordingRetention.days7);
      await notifier.ready;
      expect(container.read(recordingRetentionProvider), RecordingRetention.days7);
    });
  });

  group('RecordingRetentionService', () {
    late Directory dir;
    late NotesRepository repo;
    late DateTime now;
    late Set<String> busy;
    late String? playing;
    late RecordingRetentionService service;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('recording_retention_test_');
      repo = NotesRepository();
      now = DateTime(2026, 11, 28, 12);
      busy = {};
      playing = null;
      service = RecordingRetentionService(
        notes: repo,
        busyAudioPaths: () => busy,
        playingAudioPath: () => playing,
        now: () => now,
      );
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    /// A stored thought with a real recording of [bytes] that is [age] old.
    Future<Note> thought(
      String name, {
      Duration age = const Duration(days: 100),
      ThoughtState state = ThoughtState.processed,
      int bytes = 1000,
      bool writeFile = true,
      bool isWritten = false,
      bool withDate = true,
    }) async {
      final path = '${dir.path}/$name.wav';
      if (writeFile) await File(path).writeAsBytes(List.filled(bytes, 1));
      final note = Note(
        originalAudioPath: path,
        correctedText: 'text of $name',
        rawText: 'text of $name',
        state: state,
        isWritten: isWritten,
        createdAt: withDate ? now.subtract(age) : null,
      );
      if (!withDate) note.createdAt = null;
      await repo.saveNote(note);
      return note;
    }

    Future<Note> reload(Note n) async => (await repo.getNoteById(n.id))!;

    test('Always removes nothing, however old', () async {
      final old = await thought('old', age: const Duration(days: 3000));

      final result = await service.sweep(RecordingRetention.always);

      expect(result.count, 0);
      expect(await File(old.originalAudioPath!).exists(), isTrue);
      expect((await reload(old)).originalAudioPath, isNotNull);
    });

    test('removes the recording of a processed and of a synthesized thought older than the period, keeping their text', () async {
      final processed = await thought('a', state: ThoughtState.processed, bytes: 400);
      final synthesized = await thought('b', state: ThoughtState.synthesized, bytes: 600);
      final path = processed.originalAudioPath!;
      final otherPath = synthesized.originalAudioPath!;

      final result = await service.sweep(RecordingRetention.days30);

      expect(result.count, 2);
      expect(result.bytes, 1000);
      expect(result.failed, 0);
      expect(await File(path).exists(), isFalse);
      expect(await File(otherPath).exists(), isFalse);
      final a = await reload(processed);
      expect(a.originalAudioPath, isNull);
      expect(a.correctedText, 'text of a');
      expect(a.state, ThoughtState.processed);
      expect((await reload(synthesized)).originalAudioPath, isNull);
      expect((await reload(synthesized)).state, ThoughtState.synthesized);
    });

    test('age boundary: exactly the period old is kept, one second older is removed, newer is kept', () async {
      final exactly = await thought('exactly', age: const Duration(days: 30));
      final older = await thought('older', age: const Duration(days: 30, seconds: 1));
      final newer = await thought('newer', age: const Duration(days: 29, hours: 23));

      await service.sweep(RecordingRetention.days30);

      expect((await reload(exactly)).originalAudioPath, isNotNull);
      expect(await File(exactly.originalAudioPath!).exists(), isTrue);
      expect((await reload(older)).originalAudioPath, isNull);
      expect((await reload(newer)).originalAudioPath, isNotNull);
    });

    test('each period uses its own length', () async {
      final eightDays = await thought('eight', age: const Duration(days: 8));
      await service.sweep(RecordingRetention.days90);
      expect((await reload(eightDays)).originalAudioPath, isNotNull);
      await service.sweep(RecordingRetention.days30);
      expect((await reload(eightDays)).originalAudioPath, isNotNull);
      await service.sweep(RecordingRetention.days7);
      expect((await reload(eightDays)).originalAudioPath, isNull);
    });

    test('never touches a thought still waiting or being transcribed, or a failed one', () async {
      final waiting = await thought('waiting', state: ThoughtState.enqueued);
      final failed = await thought('failed', state: ThoughtState.failed);

      final result = await service.sweep(RecordingRetention.days7);

      expect(result.count, 0);
      for (final n in [waiting, failed]) {
        expect(await File(n.originalAudioPath!).exists(), isTrue);
        expect((await reload(n)).originalAudioPath, isNotNull);
      }
    });

    test('never touches a recording the queue still holds (waiting, transcribing, failed or silent)', () async {
      final held = await thought('held');
      busy = {held.originalAudioPath!};

      final result = await service.sweep(RecordingRetention.days7);

      expect(result.count, 0);
      expect(await File(held.originalAudioPath!).exists(), isTrue);
      expect((await reload(held)).originalAudioPath, isNotNull);
    });

    test('a silent recording is never touched: it is a queue item, not a stored thought', () async {
      final silent = File('${dir.path}/silent.wav');
      await silent.writeAsBytes([1, 2, 3]);
      busy = {silent.path};
      await thought('other');

      await service.sweep(RecordingRetention.days7);

      expect(await silent.exists(), isTrue);
    });

    test('never touches the recording that is being played, and removes it once it stops', () async {
      final playingNote = await thought('playing');
      final other = await thought('other');
      playing = playingNote.originalAudioPath;

      final during = await service.sweep(RecordingRetention.days7);
      expect(during.count, 1);
      expect(await File(playingNote.originalAudioPath!).exists(), isTrue);
      expect((await reload(playingNote)).originalAudioPath, isNotNull);
      expect((await reload(other)).originalAudioPath, isNull);

      playing = null;
      await service.sweep(RecordingRetention.days7);
      expect((await reload(playingNote)).originalAudioPath, isNull);
    });

    test('a thought whose date is unknown is never removed', () async {
      final undated = await thought('undated', withDate: false);
      await service.sweep(RecordingRetention.days7);
      expect(await File(undated.originalAudioPath!).exists(), isTrue);
    });

    test('a written thought and a thought with no path are left as they are', () async {
      final written = Note(correctedText: 'typed', isWritten: true, createdAt: now.subtract(const Duration(days: 400)));
      final noPath = Note(correctedText: 'no path', createdAt: now.subtract(const Duration(days: 400)));
      await repo.saveNote(written);
      await repo.saveNote(noPath);

      final result = await service.sweep(RecordingRetention.days7);

      expect(result.count, 0);
      expect(result.failed, 0);
      expect((await reload(written)).isWritten, isTrue);
      expect((await reload(written)).originalAudioPath, isNull);
    });

    test('a file that is already missing just clears the path and is not counted as removed', () async {
      final gone = await thought('gone', writeFile: false);

      final result = await service.sweep(RecordingRetention.days7);

      expect((await reload(gone)).originalAudioPath, isNull);
      expect(result.count, 0);
      expect(result.bytes, 0);
      expect(result.failed, 0);
    });

    test('one failing delete does not stop the others and keeps its own path for the next sweep', () async {
      final first = await thought('first');
      final bad = await thought('bad');
      final last = await thought('last');
      final failingService = RecordingRetentionService(
        notes: repo,
        busyAudioPaths: () => busy,
        playingAudioPath: () => null,
        now: () => now,
        deleteFile: (path) async {
          if (path == bad.originalAudioPath) throw const FileSystemException('locked');
          await File(path).delete();
        },
      );

      final result = await failingService.sweep(RecordingRetention.days7);

      expect(result.count, 2);
      expect(result.failed, 1);
      expect((await reload(first)).originalAudioPath, isNull);
      expect((await reload(last)).originalAudioPath, isNull);
      expect((await reload(bad)).originalAudioPath, isNotNull, reason: 'the file is still there');
      expect(await File(bad.originalAudioPath!).exists(), isTrue);
    });

    test('preview reports what a sweep would remove and changes nothing', () async {
      await thought('a', bytes: 300);
      await thought('b', bytes: 700);
      await thought('young', age: const Duration(days: 2));
      await thought('waiting', state: ThoughtState.enqueued);

      final preview = await service.preview(RecordingRetention.days30);

      expect(preview.count, 2);
      expect(preview.bytes, 1000);
      expect((await repo.getAllNotes()).where((n) => n.originalAudioPath != null).length, 4);
      expect((await service.preview(RecordingRetention.always)).count, 0);
    });

    test('measure adds up the recordings that stored thoughts point to, skipping missing files', () async {
      await thought('a', bytes: 300, age: const Duration(days: 1));
      await thought('b', bytes: 700, state: ThoughtState.synthesized);
      await thought('c', bytes: 50, state: ThoughtState.enqueued);
      await thought('gone', writeFile: false);
      await repo.saveNote(Note(correctedText: 'typed', isWritten: true));

      final size = await service.measure();

      expect(size.count, 3);
      expect(size.bytes, 1050);
    });

    test('sweepIfDue runs the first time, not again within a day, and again after a day', () async {
      final a = await thought('a');
      await service.sweepIfDue(RecordingRetention.days7);
      expect((await reload(a)).originalAudioPath, isNull);

      final b = await thought('b');
      now = now.add(const Duration(hours: 23));
      await service.sweepIfDue(RecordingRetention.days7);
      expect((await reload(b)).originalAudioPath, isNotNull, reason: 'less than a day since the last sweep');

      now = now.add(const Duration(hours: 2));
      await service.sweepIfDue(RecordingRetention.days7);
      expect((await reload(b)).originalAudioPath, isNull);
    });

    test('a sweep started while another runs does not run twice at once', () async {
      await thought('a');
      await thought('b');
      final results = await Future.wait([
        service.sweep(RecordingRetention.days7),
        service.sweep(RecordingRetention.days7),
      ]);
      expect(results[0].count + results[1].count, 2);
    });

    test('a sweep announces the change once per cleared thought through the repository', () async {
      var changes = 0;
      final observed = NotesRepository(onChanged: () => changes++);
      final n = Note(
        originalAudioPath: '${dir.path}/x.wav',
        correctedText: 'x',
        createdAt: now.subtract(const Duration(days: 100)),
      );
      await observed.saveNote(n);
      final s = RecordingRetentionService(
        notes: observed,
        busyAudioPaths: () => {},
        playingAudioPath: () => null,
        now: () => now,
      );
      final before = changes;
      await s.sweep(RecordingRetention.days7);
      expect(changes, before + 1);
    });
  });

  group('recording size wording', () {
    test('about 1.9 MB per minute: a 5 minute recording is 9.6 MB', () {
      expect(const RecordingsOnPhone(count: 1, bytes: 9600000).bytes / 5 / 1e6, closeTo(1.92, 0.01));
    });

    test('sizes read as MB, with a decimal below 10 MB, and as GB from 1000 MB', () {
      expect(formatRecordingSize(0), '0 MB');
      expect(formatRecordingSize(400000), 'under 1 MB');
      expect(formatRecordingSize(1500000), '1.5 MB');
      expect(formatRecordingSize(9600000), '9.6 MB');
      expect(formatRecordingSize(132400000), '132 MB');
      expect(formatRecordingSize(1300000000), '1.3 GB');
    });

    test('the "on this phone" line', () {
      expect(recordingsOnPhoneLine(const RecordingsOnPhone(count: 60, bytes: 132000000)),
          'Recordings on this phone: 132 MB in 60 recordings');
      expect(recordingsOnPhoneLine(const RecordingsOnPhone(count: 1, bytes: 1900000)),
          'Recordings on this phone: 1.9 MB in 1 recording');
      expect(recordingsOnPhoneLine(const RecordingsOnPhone(count: 0, bytes: 0)), 'No recordings are kept on this phone.');
    });
  });
}
