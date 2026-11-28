import 'package:eudemonia/features/synthesis/domain/session_numbering.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';

/// The question asked before a thought is deleted, naming it by the number its card shows.
String deleteThoughtQuestion(int? sequenceNumber) =>
    sequenceNumber == null ? 'Delete this thought?' : 'Delete thought #${sequenceNumber.toString().padLeft(2, '0')}?';

/// What else changes when thought [noteId] is deleted, or null when nothing does.
///
/// Mirrors what `SynthesisRepository.removeThought` really does with the [session] holding the
/// thought: a session left without thoughts is deleted; otherwise its note is rewritten from the
/// thoughts that remain, except a note edited by hand, which is never rewritten automatically and
/// only loses the thought from the list it was written from.
String? describeThoughtDeleteConsequence({
  required SynthesisCluster? session,
  required int noteId,
  required DateTime? thoughtCreatedAt,
}) {
  if (session == null) return null;
  final label = sessionReferenceLabel(session, relativeTo: thoughtCreatedAt ?? session.sessionStart);
  final note = 'Note $label "${noteListTitle(session.synthesizedContent)}"';
  final others = session.originNotes.where((o) => o.id != noteId);
  if (others.isEmpty) return '$note will be deleted too.';
  if (session.isHandEdited) {
    return '$note was edited by hand, so its text stays as it is; this thought is only removed from its source thoughts.';
  }
  return '$note will be rewritten without this thought.';
}
