import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/features/notes/application/read_state_migration.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<NotesRepository> repoWith(List<Note> notes) async {
    final repo = NotesRepository();
    for (final n in notes) {
      await repo.saveNote(n);
    }
    return repo;
  }

  test('the first start marks synthesized thoughts read and leaves the others alone', () async {
    final synthesized = Note(correctedText: 'Clubbed', state: ThoughtState.synthesized);
    final processed = Note(correctedText: 'Fresh', state: ThoughtState.processed);
    final repo = await repoWith([synthesized, processed]);

    expect(await migrateReadFollowsViewing(repo), 1);

    expect((await repo.getNoteById(synthesized.id))!.isRead, isTrue);
    expect((await repo.getNoteById(processed.id))!.isRead, isFalse);
    expect((await SharedPreferences.getInstance()).getBool('capture.readFollowsViewing'), isTrue);
  });

  test('it runs once: a thought synthesized later stays unread', () async {
    final repo = await repoWith([]);
    expect(await migrateReadFollowsViewing(repo), 0);

    final later = Note(correctedText: 'Synthesized after the update', state: ThoughtState.synthesized);
    await repo.saveNote(later);
    expect(await migrateReadFollowsViewing(repo), 0);

    expect((await repo.getNoteById(later.id))!.isRead, isFalse);
  });

  test('an already set flag changes nothing', () async {
    SharedPreferences.setMockInitialValues({'capture.readFollowsViewing': true});
    final clubbed = Note(correctedText: 'Clubbed', state: ThoughtState.synthesized);
    final repo = await repoWith([clubbed]);

    expect(await migrateReadFollowsViewing(repo), 0);
    expect((await repo.getNoteById(clubbed.id))!.isRead, isFalse);
  });
}
