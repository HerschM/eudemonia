import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';

/// Saves a thought the user typed in the app (the written-note counterpart of a recording that
/// has been transcribed): processed, already read, no audio, numbered with the day's next daily
/// sequence number like any other thought. The one entry point; screens never build a [Note]
/// for it themselves.
class WrittenNoteCapture {
  final NotesRepository _notes;

  /// The next daily sequence number of a day, from the numbering voice thoughts use.
  final Future<int> Function(DateTime day) _nextSequenceNumber;

  /// Told after the thought is stored (the automatic synthesis trigger counts waiting thoughts).
  final void Function() _onSaved;
  final DateTime Function() _now;

  WrittenNoteCapture({
    required this._notes,
    required this._nextSequenceNumber,
    required this._onSaved,
    this._now = DateTime.now,
  });

  /// Stores [text] (trimmed) as a written thought and returns it, or returns null and stores
  /// nothing when it is empty.
  Future<Note?> save(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final createdAt = _now();
    final note = Note(
      rawText: trimmed,
      correctedText: trimmed,
      createdAt: createdAt,
      dailySequenceNumber: await _nextSequenceNumber(createdAt),
      state: ThoughtState.processed,
      isRead: true,
      isWritten: true,
    );
    await _notes.saveNote(note);
    _onSaved();
    return note;
  }
}

final writtenNoteCaptureProvider = Provider<WrittenNoteCapture>((ref) {
  final notes = ref.watch(notesRepositoryProvider);
  return WrittenNoteCapture(
    notes: notes,
    // The queue owns the numbering: one counter for recordings and written notes.
    nextSequenceNumber: (day) => ref.read(audioQueueServiceProvider).reserveSequenceNumber(day),
    onSaved: () => unawaited(ref.read(synthesisTriggerControllerProvider).onThoughtSaved()),
  );
});
