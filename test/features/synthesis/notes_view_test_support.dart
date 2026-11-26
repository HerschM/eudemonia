import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';

/// [NotesViewPrefsStore] in memory, so Synthesis tests never touch shared preferences.
class InMemoryNotesViewPrefsStore implements NotesViewPrefsStore {
  NotesViewPrefs? stored;
  int saves = 0;

  InMemoryNotesViewPrefsStore([this.stored]);

  @override
  Future<NotesViewPrefs?> load() async => stored;

  @override
  Future<void> save(NotesViewPrefs prefs) async {
    saves++;
    stored = prefs;
  }
}

/// Every note shown in full, with its actions.
const NotesViewPrefs openEditPrefs = NotesViewPrefs(readMode: false, notesOpenByDefault: true);

/// Every note shown in full, read only.
const NotesViewPrefs openReadPrefs = NotesViewPrefs(readMode: true, notesOpenByDefault: true);
