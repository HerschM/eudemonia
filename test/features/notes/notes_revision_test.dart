import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

void main() {
  group('notesRevisionProvider: one "notes changed" signal', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    Future<int> readyCount() => container.read(rawNotesReadyToClusterCountProvider.future);
    Future<List<Note>> recent() => container.read(recentNotesProvider.future);

    test('saving a processed thought raises the ready count and refreshes the list without manual invalidation', () async {
      final repo = container.read(notesRepositoryProvider);
      expect(await readyCount(), 0);
      expect(await recent(), isEmpty);

      await repo.saveNote(Note(correctedText: 'First', state: ThoughtState.processed));
      expect(await readyCount(), 1);
      expect((await recent()).map((n) => n.correctedText), ['First']);

      await repo.saveNote(Note(correctedText: 'Second', state: ThoughtState.processed));
      expect(await readyCount(), 2);
      expect(await recent(), hasLength(2));
    });

    test('a thought still enqueued does not count; finishing it does', () async {
      final repo = container.read(notesRepositoryProvider);
      final note = Note(correctedText: 'Pending', state: ThoughtState.enqueued);
      await repo.saveNote(note);
      expect(await readyCount(), 0);

      note.state = ThoughtState.processed;
      await repo.saveNote(note);
      expect(await readyCount(), 1);
    });

    test('deleting a thought lowers the ready count and shrinks the list', () async {
      final repo = container.read(notesRepositoryProvider);
      final note = Note(correctedText: 'Gone soon', state: ThoughtState.processed);
      await repo.saveNote(note);
      expect(await readyCount(), 1);
      expect(await recent(), hasLength(1));

      await repo.deleteNote(note.id);
      expect(await readyCount(), 0);
      expect(await recent(), isEmpty);
    });

    test('editing and marking read each bump the revision', () async {
      final repo = container.read(notesRepositoryProvider);
      final note = Note(correctedText: 'Draft', state: ThoughtState.processed);
      await repo.saveNote(note);
      var revision = container.read(notesRevisionProvider);

      await repo.updateNoteText(note.id, 'Edited');
      expect(container.read(notesRevisionProvider), greaterThan(revision));
      expect((await recent()).single.correctedText, 'Edited');

      revision = container.read(notesRevisionProvider);
      await repo.markAsRead(note.id);
      expect(container.read(notesRevisionProvider), greaterThan(revision));
      expect((await recent()).single.isRead, isTrue);
    });

    test('a repository built without a callback still works', () async {
      final repo = NotesRepository();
      await repo.saveNote(Note(correctedText: 'Plain'));
      expect(await repo.getAllNotes(), hasLength(1));
    });

    test('a change after the container is disposed does not throw', () async {
      final local = ProviderContainer();
      final repo = local.read(notesRepositoryProvider);
      local.dispose();
      await repo.saveNote(Note(correctedText: 'Late'));
    });
  });
}
