import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'note_model.dart';

class NotesRepository {
  Isar? _isar;
  bool _isInitialized = false;
  final List<Note> _inMemoryNotes = [];
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
    if (note.dailySequenceNumber == null) {
      final date = note.createdAt ?? DateTime.now();
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      int maxSeq = 0;
      if (_isar != null) {
        final sameDayNotes = await _isar!.notes
            .filter()
            .createdAtBetween(startOfDay, endOfDay)
            .findAll();
        for (final n in sameDayNotes) {
          if (n.dailySequenceNumber != null && n.dailySequenceNumber! > maxSeq) {
            maxSeq = n.dailySequenceNumber!;
          }
        }
      } else {
        for (final n in _inMemoryNotes) {
          final nDate = n.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (nDate.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
              nDate.isBefore(endOfDay.add(const Duration(milliseconds: 1)))) {
            if (n.dailySequenceNumber != null && n.dailySequenceNumber! > maxSeq) {
              maxSeq = n.dailySequenceNumber!;
            }
          }
        }
      }
      note.dailySequenceNumber = maxSeq + 1;
    }

    if (_isar != null) {
      await _isar!.writeTxn(() async {
        await _isar!.notes.put(note);
      });
    } else {
      if (note.id == Isar.autoIncrement || note.id == 0) {
        note.id = _nextId++;
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
    if (_isar != null) {
      return await _isar!.notes.get(id);
    } else {
      return _inMemoryNotes.where((n) => n.id == id).firstOrNull;
    }
  }

  Future<void> deleteNote(Id id) async {
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        await _isar!.notes.delete(id);
      });
    } else {
      _inMemoryNotes.removeWhere((n) => n.id == id);
    }
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
    if (_isar != null) {
      await _isar!.writeTxn(() async {
        final note = await _isar!.notes.get(id);
        if (note != null) {
          note.isRead = true;
          await _isar!.notes.put(note);
        }
      });
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
    final notes = _isar != null
        ? await _isar!.notes.where().sortByCreatedAtDesc().findAll()
        : (List<Note>.from(_inMemoryNotes)
          ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))));

    // Backfill legacy notes missing dailySequenceNumber chronologically per day
    if (notes.any((n) => n.dailySequenceNumber == null)) {
      final byDay = <String, List<Note>>{};
      for (final n in notes) {
        final d = n.createdAt ?? DateTime.now();
        final key = '${d.year}-${d.month}-${d.day}';
        byDay.putIfAbsent(key, () => []).add(n);
      }
      for (final dayNotes in byDay.values) {
        dayNotes.sort((a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
        int seq = 1;
        for (final n in dayNotes) {
          if (n.dailySequenceNumber == null) {
            n.dailySequenceNumber = seq;
            if (_isar != null && n.id > 0) {
              await _isar!.writeTxn(() async {
                await _isar!.notes.put(n);
              });
            }
          }
          seq = (n.dailySequenceNumber ?? seq) + 1;
        }
      }
    }

    return notes;
  }

  Future<List<Note>> searchNotes(String query) async {
    if (_isar != null) {
      return await _isar!.notes
          .filter()
          .correctedTextContains(query, caseSensitive: false)
          .or()
          .folderContains(query, caseSensitive: false)
          .sortByCreatedAtDesc()
          .findAll();
    } else {
      final q = query.toLowerCase();
      return _inMemoryNotes
          .where((n) =>
              n.correctedText.toLowerCase().contains(q) ||
              n.folder.toLowerCase().contains(q))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    }
  }

  Future<List<Note>> getNotesByFolder(String folder) async {
    if (_isar != null) {
      return await _isar!.notes
          .filter()
          .folderEqualTo(folder)
          .sortByCreatedAtDesc()
          .findAll();
    } else {
      return _inMemoryNotes
          .where((n) => n.folder == folder)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    }
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
