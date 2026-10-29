import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  group('TASK-035 Unit Tests: Unread / Viewed Thought Status Tracking', () {
    late NotesRepository repo;

    setUp(() {
      repo = NotesRepository();
    });

    test('1. New notes are created with isRead = false', () async {
      final note = Note(
        correctedText: 'Fresh unread thought',
        folder: 'Ideas',
      );
      expect(note.isRead, isFalse);

      await repo.saveNote(note);
      final retrieved = await repo.getNoteById(note.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.isRead, isFalse);
    });

    test('2. markAsRead(id) updates note in database', () async {
      final note = Note(
        correctedText: 'Thought to be marked read',
        folder: 'Work',
      );
      await repo.saveNote(note);

      await repo.markAsRead(note.id);

      final retrieved = await repo.getNoteById(note.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.isRead, isTrue);
    });

    test('3. getUnreadNotes() queries only notes where isRead == false', () async {
      final note1 = Note(correctedText: 'Note 1', folder: 'Work');
      final note2 = Note(correctedText: 'Note 2', folder: 'Ideas');
      final note3 = Note(correctedText: 'Note 3', folder: 'Todos');

      await repo.saveNote(note1);
      await repo.saveNote(note2);
      await repo.saveNote(note3);

      await repo.markAsRead(note2.id);

      final unread = await repo.getUnreadNotes();
      expect(unread.length, equals(2));
      final unreadIds = unread.map((n) => n.id).toList();
      expect(unreadIds.contains(note1.id), isTrue);
      expect(unreadIds.contains(note3.id), isTrue);
      expect(unreadIds.contains(note2.id), isFalse);
    });
  });
}
