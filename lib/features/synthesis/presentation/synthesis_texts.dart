import 'package:eudemonia/core/formatting/thought_timestamp.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';

/// The one wording for how many thoughts are waiting for Synthesis, with correct singular and plural.
/// Shared by the Synthesis banner, the Pipeline HUD and Settings.
String describeThoughtsReadyForSynthesis(int count) =>
    '$count ${count == 1 ? 'thought' : 'thoughts'} ready for Synthesis';

/// The quiet line under the actions of a hand-edited note.
const String handEditedNotice =
    'Edited by hand. It is not rewritten automatically; new thoughts are added underneath.';

/// Asked before a style rewrite of a hand-edited note.
const String rewriteReplacesEditsWarning = 'Rewriting in a style replaces your own edits to this note.';

/// Shown in the text editor when an empty text is refused.
const String emptyNoteRefusal = 'A note cannot be empty.';

/// `From 3 thoughts`, the link that reveals the thoughts a note was written from.
String describeNoteOrigin(int thoughtCount) => 'From $thoughtCount ${thoughtCount == 1 ? 'thought' : 'thoughts'}';

/// A note's time on its row: `02:35 PM`.
String formatNoteTime(DateTime time) => formatThoughtTimestamp(time).split('  ').last;

/// Start time of a note, plus the session length once it reaches a minute.
String describeSessionSpan(DateTime start, Duration length) {
  final date = formatThoughtTimestamp(start);
  if (length.inMinutes < 1) return date;
  final minutes = length.inMinutes;
  final text = minutes < 60 ? '${minutes}m session' : '${length.inHours}h ${minutes % 60}m session';
  return '$date • ⏱️ $text';
}

/// The title a note is listed under: its title block, else its first words.
String noteListTitle(String markdown, {int maxWords = 8}) {
  final blocks = parseNoteMarkdown(markdown);
  if (blocks.isNotEmpty && blocks.first.kind == NoteBlockKind.title && blocks.first.text.trim().isNotEmpty) {
    return blocks.first.text.trim();
  }
  final words = plainNotePreview(markdown).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'Empty note';
  final shown = words.take(maxWords).join(' ');
  return words.length > maxWords ? '$shown…' : shown;
}
