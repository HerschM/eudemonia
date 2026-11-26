import 'package:shared_preferences/shared_preferences.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

/// `shared_preferences` flag: thoughts are read when the user has seen them, whatever their state.
const readFollowsViewingFlag = 'capture.readFollowsViewing';

/// Once, the first time this version starts: thoughts that are already synthesized are marked
/// read. Until now a synthesized thought counted as consumed whether or not it had been seen,
/// so the Capture count must not jump up for existing users. Returns how many were marked.
/// Never throws: on any failure the flag stays unset and the migration runs again next start.
Future<int> migrateReadFollowsViewing(NotesRepository notes, {AppLogger? logger}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(readFollowsViewingFlag) ?? false) return 0;
    var marked = 0;
    for (final note in await notes.getAllNotes()) {
      if (note.state == ThoughtState.synthesized && !note.isRead) {
        await notes.markAsRead(note.id);
        marked++;
      }
    }
    await prefs.setBool(readFollowsViewingFlag, true);
    if (marked > 0) logger?.info('[Notes] Marked $marked synthesized thought(s) as read (one-time migration).');
    return marked;
  } catch (e, stack) {
    logger?.error('[Notes] Read-state migration failed; it will run again next start', error: e, stackTrace: stack);
    return 0;
  }
}
