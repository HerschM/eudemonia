import 'dart:io';
import 'package:isar_community/isar.dart';
import 'package:eudemonia/core/database/app_database.dart';
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
    _isar = await openAppDatabase(directory: directory);
    _isInitialized = true;
  }

  /// Highest daily sequence number already assigned on the calendar day of [day], or 0.
  Future<int> maxDailySequenceFor(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    final Iterable<Note> sameDayNotes;
    if (_isar != null) {
      sameDayNotes = await _isar!.notes
          .filter()
          .createdAtBetween(startOfDay, endOfDay)
          .findAll();
    } else {
      sameDayNotes = _inMemoryNotes.where((n) {
        final nDate = n.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return !nDate.isBefore(startOfDay) && !nDate.isAfter(endOfDay);
      });
    }

    int maxSeq = 0;
    for (final n in sameDayNotes) {
      final seq = n.dailySequenceNumber;
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }
    return maxSeq;
  }

  Future<void> saveNote(Note note) async {
    if (note.dailySequenceNumber == null) {
      final maxSeq = await maxDailySequenceFor(note.createdAt ?? DateTime.now());
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

  /// Deletes the note together with its raw audio recording.
  Future<void> deleteNote(Id id) async {
    final audioPath = (await getNoteById(id))?.originalAudioPath;

    if (_isar != null) {
      await _isar!.writeTxn(() async {
        await _isar!.notes.delete(id);
      });
    } else {
      _inMemoryNotes.removeWhere((n) => n.id == id);
    }

    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        final file = File(audioPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // The note is gone either way; a stray recording must not fail the delete.
      }
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
  return NotesRepository(isar: ref.watch(appDatabaseProvider));
});

final recentNotesProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getAllNotes();
});
