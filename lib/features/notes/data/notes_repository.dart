import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'note_model.dart';

class NotesRepository {
  late Isar _isar;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteSchema],
      directory: dir.path,
    );
    _isInitialized = true;
  }

  Future<void> saveNote(Note note) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  Future<List<Note>> getAllNotes() async {
    return await _isar.notes.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<Note>> searchNotes(String query) async {
    return await _isar.notes
        .filter()
        .correctedTextContains(query, caseSensitive: false)
        .or()
        .folderContains(query, caseSensitive: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<Note>> getNotesByFolder(String folder) async {
    return await _isar.notes
        .filter()
        .folderEqualTo(folder)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<String>> getAllFolders() async {
    final notes = await _isar.notes.where().findAll();
    final folders = notes.map((n) => n.folder).toSet().toList();
    if (folders.isEmpty) {
      folders.addAll(['Work', 'Ideas', 'Todos', 'Journal']);
    }
    return folders;
  }
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});
