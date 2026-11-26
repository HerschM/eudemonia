import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

/// What the user does to a stored thought in Capture, kept consistent with Synthesis: a session
/// that consumed the thought never keeps a deleted thought or the old text of an edited one.
class ThoughtActions {
  final NotesRepository _notes;
  final SynthesisRepository _sessions;

  /// Starts a synthesis run so a flagged session is rewritten without waiting for a new thought.
  /// Not awaited: a busy, preempted or model-less run leaves the flag for the next run.
  final Future<SynthesisRunResult> Function() _startRewrite;

  ThoughtActions({
    required this._notes,
    required this._sessions,
    required this._startRewrite,
  });

  /// Deletes the thought and its recording, and takes it out of the session that holds it.
  Future<void> delete(Note note) async {
    await _notes.deleteNote(note.id);
    await _sessions.hydrated;
    if (_sessions.removeThought(note.id)) unawaited(_startRewrite());
  }

  /// Replaces the thought's text, also in the session that holds it.
  Future<void> editText(Note note, String newText) async {
    await _notes.updateNoteText(note.id, newText);
    await _sessions.hydrated;
    // The text a session reads for a thought (an empty correction falls back to the transcript).
    final text = newText.isNotEmpty ? newText : note.rawText;
    if (_sessions.updateThoughtText(note.id, text)) unawaited(_startRewrite());
  }
}

final thoughtActionsProvider = Provider<ThoughtActions>((ref) {
  return ThoughtActions(
    notes: ref.watch(notesRepositoryProvider),
    sessions: ref.watch(synthesisRepositoryProvider.notifier),
    // Read only when a rewrite is due, so Capture does not build the runner up front.
    startRewrite: () => ref.read(synthesisRunnerProvider).run(manual: true),
  );
});
