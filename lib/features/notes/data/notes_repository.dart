import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'note_model.dart';

class NotesRepository {
  Isar? _isar;
  bool _isInitialized = false;
  final List<Note> _inMemoryNotes = [];
  final Set<Id> _readNoteIds = {};
  int _nextId = 1;

  NotesRepository({Isar? isar})
      : _isar = isar,
        _isInitialized = isar != null;

  Future<void> init({String? directory}) async {
    if (_isInitialized) return;
    final dirPath = directory ?? (await getApplicationDocumentsDirectory()).path;
    _isar = await Isar.open(
      [NoteSchema],
      directory: dirPath,
    );
    _isInitialized = true;
  }

  Future<void> saveNote(Note note) async {
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        await _isar!.notes.put(note);
      });
      if (note.isRead) {
        _readNoteIds.add(note.id);
      }
    } else {
      if (note.id == Isar.autoIncrement || note.id == 0) {
        note.id = _nextId++;
      }
      if (note.isRead) {
        _readNoteIds.add(note.id);
      }
      final existingIndex = _inMemoryNotes.indexWhere((n) => n.id == note.id);
      if (existingIndex >= 0) {
        _inMemoryNotes[existingIndex] = note;
      } else {
        _inMemoryNotes.add(note);
      }
    }
  }

  Future<Note?> getNoteById(Id id) async {
    Note? note;
    if (_isar != null) {
      note = await _isar!.notes.get(id);
    } else {
      note = _inMemoryNotes.where((n) => n.id == id).firstOrNull;
    }
    if (note != null) {
      note.isRead = _readNoteIds.contains(note.id);
    }
    return note;
  }

  Future<void> updateNoteText(Id id, String newText) async {
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        final note = await _isar!.notes.get(id);
        if (note != null) {
          note.correctedText = newText;
          await _isar!.notes.put(note);
        }
      });
    } else {
      final note = _inMemoryNotes.where((n) => n.id == id).firstOrNull;
      if (note != null) {
        note.correctedText = newText;
      }
    }
  }

  Future<void> updateNoteFolder(Id id, String newFolder) async {
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        final note = await _isar!.notes.get(id);
        if (note != null) {
          note.folder = newFolder;
          await _isar!.notes.put(note);
        }
      });
    } else {
      final note = _inMemoryNotes.where((n) => n.id == id).firstOrNull;
      if (note != null) {
        note.folder = newFolder;
      }
    }
  }

  Future<void> markAsRead(Id id) async {
    _readNoteIds.add(id);
    if (_isar != null) {
      final note = await _isar!.notes.get(id);
      if (note != null) {
        note.isRead = true;
      }
    } else {
      final note = _inMemoryNotes.where((n) => n.id == id).firstOrNull;
      if (note != null) {
        note.isRead = true;
      }
    }
  }

  Future<List<Note>> getUnreadNotes() async {
    final all = await getAllNotes();
    return all.where((n) => !n.isRead).toList();
  }

  Future<List<Note>> getAllNotes() async {
    List<Note> list;
    if (_isar != null) {
      list = await _isar!.notes.where().sortByCreatedAtDesc().findAll();
    } else {
      list = List<Note>.from(_inMemoryNotes)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    for (final n in list) {
      n.isRead = _readNoteIds.contains(n.id);
    }
    return list;
  }

  Future<List<Note>> searchNotes(String query) async {
    List<Note> list;
    if (_isar != null) {
      list = await _isar!.notes
          .filter()
          .correctedTextContains(query, caseSensitive: false)
          .or()
          .folderContains(query, caseSensitive: false)
          .sortByCreatedAtDesc()
          .findAll();
    } else {
      final q = query.toLowerCase();
      list = _inMemoryNotes
          .where((n) =>
              n.correctedText.toLowerCase().contains(q) ||
              n.folder.toLowerCase().contains(q))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    for (final n in list) {
      n.isRead = _readNoteIds.contains(n.id);
    }
    return list;
  }

  Future<List<Note>> getNotesByFolder(String folder) async {
    List<Note> list;
    if (_isar != null) {
      list = await _isar!.notes
          .filter()
          .folderEqualTo(folder)
          .sortByCreatedAtDesc()
          .findAll();
    } else {
      list = _inMemoryNotes
          .where((n) => n.folder == folder)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    for (final n in list) {
      n.isRead = _readNoteIds.contains(n.id);
    }
    return list;
  }

  Future<List<String>> getAllFolders() async {
    List<Note> notes;
    if (_isar != null) {
      notes = await _isar!.notes.where().findAll();
    } else {
      notes = _inMemoryNotes;
    }
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

final recentNotesProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getAllNotes();
});
