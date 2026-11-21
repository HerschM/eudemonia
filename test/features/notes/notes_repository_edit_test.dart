import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  group('TASK-034 Unit Tests: NotesRepository Inline Edit & Category Reassignment', () {
    late NotesRepository repo;

    setUp(() {
      repo = NotesRepository();
    });

    test('1. updateNoteText(id, newText) persists updated text to database', () async {
      final note = Note(
        correctedText: 'Original thought text',
      );
      await repo.saveNote(note);
      expect(note.id, isNotNull);

      await repo.updateNoteText(note.id, 'Edited thought text');

      final updated = await repo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.correctedText, equals('Edited thought text'));
    });

    test('3. deleteNote(id) permanently removes note from repository', () async {
      final note = Note(
        correctedText: 'Note to be deleted',
      );
      await repo.saveNote(note);
      expect(await repo.getNoteById(note.id), isNotNull);

      await repo.deleteNote(note.id);
      expect(await repo.getNoteById(note.id), isNull);
      final all = await repo.getAllNotes();
      expect(all.any((n) => n.id == note.id), isFalse);
    });
  });
}
