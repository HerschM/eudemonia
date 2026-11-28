import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

/// How many thoughts waiting for Synthesis have already failed a run (FR11.28): still waiting in
/// Capture with at least one counted attempt (`SynthesisRunner` counts an attempt for every
/// thought a run takes, takes it back from thoughts the run never tried, and a written thought
/// leaves the waiting state). Behind the second line of the Synthesis banner.
final unwrittenThoughtsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(notesRevisionProvider);
  final notes = await ref.watch(notesRepositoryProvider).getAllNotes();
  return notes.where((n) => n.state == ThoughtState.processed && n.synthesisAttempts > 0).length;
});
