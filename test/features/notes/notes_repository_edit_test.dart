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
        folder: 'Ideas',
      );
      await repo.saveNote(note);
      expect(note.id, isNotNull);

      await repo.updateNoteText(note.id, 'Edited thought text');

      final updated = await repo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.correctedText, equals('Edited thought text'));
    });

    test('2. updateNoteFolder(id, newFolder) persists updated folder to database', () async {
      final note = Note(
        correctedText: 'Meeting notes',
        folder: 'Ideas',
      );
      await repo.saveNote(note);

      await repo.updateNoteFolder(note.id, 'Work');

      final updated = await repo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.folder, equals('Work'));
    });
  });
}
