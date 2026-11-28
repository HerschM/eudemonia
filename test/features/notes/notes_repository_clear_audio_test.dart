import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  test('clearAudioPath empties only the recording path and announces the change', () async {
    var changes = 0;
    final repo = NotesRepository(onChanged: () => changes++);
    final note = Note(originalAudioPath: '/a/b.wav', rawText: 'raw', correctedText: 'text', isRead: true);
    await repo.saveNote(note);
    final before = changes;

    await repo.clearAudioPath(note.id);

    final stored = (await repo.getNoteById(note.id))!;
    expect(stored.originalAudioPath, isNull);
    expect(stored.correctedText, 'text');
    expect(stored.rawText, 'raw');
    expect(stored.isRead, isTrue);
    expect(stored.state, ThoughtState.processed);
    expect(changes, before + 1);
  });

  test('clearAudioPath on a thought that no longer exists changes nothing and does not throw', () async {
    final repo = NotesRepository();
    await repo.clearAudioPath(12345);
    expect(await repo.getAllNotes(), isEmpty);
  });
}
