import 'package:eudemonia/features/capture/thought_actions.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NotesRepository notes;
  late SynthesisSessionStore store;
  late ProviderContainer container;
  late int rewrites;

  setUp(() {
    notes = NotesRepository();
    store = SynthesisSessionStore();
    rewrites = 0;
    container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(notes),
      synthesisSessionStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
  });

  SynthesisRepository sessions() => container.read(synthesisRepositoryProvider.notifier);

  ThoughtActions actions() => ThoughtActions(
        notes: notes,
        sessions: sessions(),
        startRewrite: () async {
          rewrites++;
          return SynthesisRunResult.busy;
        },
      );

  Future<Note> thought(String text, int minute, {ThoughtState state = ThoughtState.synthesized}) async {
    final n = Note(correctedText: text, createdAt: DateTime(2026, 11, 26, 9, minute), state: state);
    await notes.saveNote(n);
    return n;
  }

  Future<SynthesisCluster> session(List<Note> thoughts) async {
    await sessions().hydrated;
    return sessions().createSession(
      folder: 'Work',
      note: thoughts.map((t) => t.correctedText).join(' '),
      origins: [for (final t in thoughts) SynthesisOriginNote.fromNote(t)],
    );
  }

  SynthesisCluster? only() => container.read(synthesisRepositoryProvider).singleOrNull;

  group('delete', () {
    test('removes the note, its origin from the session, flags the session and starts a rewrite', () async {
      final a = await thought('Plan the release.', 0);
      final b = await thought('Move it to Monday.', 10);
      await session([a, b]);

      await actions().delete(b);

      expect(await notes.getNoteById(b.id), isNull);
      final s = only()!;
      expect(s.originNotes.map((o) => o.id), [a.id]);
      expect(s.isReprocessing, isTrue);
      expect(s.synthesizedContent, 'Plan the release. Move it to Monday.', reason: 'rewritten by the run, not here');
      expect(rewrites, 1);
      await sessions().pendingWrites;
      expect((await store.loadAll()).single.isReprocessing, isTrue, reason: 'the flag survives a restart');
    });

    test('deleting the only thought of a session removes the session; no rewrite is needed', () async {
      final a = await thought('Plan the release.', 0);
      await session([a]);

      await actions().delete(a);

      expect(container.read(synthesisRepositoryProvider), isEmpty);
      expect(rewrites, 0);
      await sessions().pendingWrites;
      expect(await store.loadAll(), isEmpty);
    });

    test('deleting a thought not yet synthesized touches no session', () async {
      final a = await thought('Plan the release.', 0);
      final waiting = await thought('Buy milk.', 20, state: ThoughtState.processed);
      final before = await session([a]);

      await actions().delete(waiting);

      expect(await notes.getNoteById(waiting.id), isNull);
      expect(identical(only(), before), isTrue);
      expect(rewrites, 0);
    });
  });

  group('editText', () {
    test('updates the note and the origin text, flags the session and starts a rewrite', () async {
      final a = await thought('Plan the release.', 0);
      final b = await thought('Move it to Monday.', 10);
      await session([a, b]);

      await actions().editText(b, 'Move it to Tuesday.');

      expect((await notes.getNoteById(b.id))!.correctedText, 'Move it to Tuesday.');
      final s = only()!;
      expect(s.originNotes.map((o) => o.cleanedText), ['Plan the release.', 'Move it to Tuesday.']);
      expect(s.isReprocessing, isTrue);
      expect(rewrites, 1);
    });

    test('editing a thought not yet synthesized touches no session', () async {
      final a = await thought('Plan the release.', 0);
      final waiting = await thought('Buy milk.', 20, state: ThoughtState.processed);
      final before = await session([a]);

      await actions().editText(waiting, 'Buy oat milk.');

      expect((await notes.getNoteById(waiting.id))!.correctedText, 'Buy oat milk.');
      expect(identical(only(), before), isTrue);
      expect(rewrites, 0);
    });

    test('an edit that leaves the text as it was starts no rewrite', () async {
      final a = await thought('Plan the release.', 0);
      await session([a]);

      await actions().editText(a, 'Plan the release.');

      expect(only()!.isReprocessing, isFalse);
      expect(rewrites, 0);
    });
  });
}
