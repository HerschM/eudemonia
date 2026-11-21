import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/audio_playback_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotesRepository audio cleanup & sequence lookup', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('notes_cleanup_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('deleteNote removes the raw audio recording from disk', () async {
      final audio = File('${tempDir.path}/recording_1.wav');
      await audio.writeAsBytes([0, 1, 2, 3]);
      final repo = NotesRepository();
      final note = Note(correctedText: 'Private thought', originalAudioPath: audio.path);
      await repo.saveNote(note);

      await repo.deleteNote(note.id);

      expect(await repo.getNoteById(note.id), isNull);
      expect(await audio.exists(), isFalse);
    });

    test('deleteNote succeeds when the recording is already gone', () async {
      final repo = NotesRepository();
      final note = Note(correctedText: 'No audio', originalAudioPath: '${tempDir.path}/missing.wav');
      await repo.saveNote(note);

      await repo.deleteNote(note.id);

      expect(await repo.getAllNotes(), isEmpty);
    });

    test('maxDailySequenceFor only considers notes from the given calendar day', () async {
      final repo = NotesRepository();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      await repo.saveNote(Note(correctedText: 'old', createdAt: yesterday, dailySequenceNumber: 9));
      await repo.saveNote(Note(correctedText: 'new', createdAt: today, dailySequenceNumber: 2));

      expect(await repo.maxDailySequenceFor(today), 2);
      expect(await repo.maxDailySequenceFor(yesterday), 9);
      expect(await repo.maxDailySequenceFor(today.add(const Duration(days: 1))), 0);
    });
  });

  group('AudioPlaybackController native failure handling', () {
    const channel = MethodChannel('com.eudemonia/audio_playback');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('a native playback error never leaves the card in a "playing" state', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'FILE_NOT_FOUND', message: 'Audio file does not exist');
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(audioPlaybackControllerProvider.notifier).play('/gone.wav');

      final state = container.read(audioPlaybackControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.currentlyPlayingPath, isNull);
    });
  });

  group('SynthesisRepository session identifiers', () {
    test('a new session never reuses the identifier of an existing one after a deletion', () async {
      final notesRepo = NotesRepository();
      final container = ProviderContainer(
        overrides: [notesRepositoryProvider.overrideWithValue(notesRepo)],
      );
      addTearDown(container.dispose);
      final synthesis = container.read(synthesisRepositoryProvider.notifier);

      await synthesis.synthesizeRawNotes([Note(correctedText: 'a')]);
      await synthesis.synthesizeRawNotes([Note(correctedText: 'b')]);
      final firstId = container
          .read(synthesisRepositoryProvider)
          .firstWhere((c) => c.sequenceNumber == '#S-01')
          .clusterId;
      await synthesis.deleteCluster(firstId);

      await synthesis.synthesizeRawNotes([Note(correctedText: 'c')]);

      final ids = container.read(synthesisRepositoryProvider).map((c) => c.sequenceNumber).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['#S-02', '#S-03']));
    });
  });
}
