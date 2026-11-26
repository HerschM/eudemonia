/// Display-only parser for the light Markdown the language model writes into a synthesized
/// note. Parsing never changes the stored text (it is Markdown and is exported as such); it only
/// decides how it is drawn. The one edit is [setTaskChecked], which ticks a task's box.
library;

/// [task] is a Markdown task-list line, `- [ ] text` or `- [x] text`.
enum NoteBlockKind { title, heading, bullet, task, paragraph }

/// A run of text inside a block; [bold] comes from `**…**`.
class NoteSpan {
  final String text;
  final bool bold;

  const NoteSpan(this.text, {this.bold = false});

  @override
  bool operator ==(Object other) =>
      other is NoteSpan && other.text == text && other.bold == bold;

  @override
  int get hashCode => Object.hash(text, bold);

  @override
  String toString() => bold ? '**$text**' : text;
}

class NoteBlock {
  final NoteBlockKind kind;
  final List<NoteSpan> spans;

  /// Whether a task's box is ticked; false for every other kind.
  final bool checked;

  /// A task's zero-based position among the note's tasks (see [setTaskChecked]); null otherwise.
  final int? taskIndex;

  const NoteBlock(this.kind, this.spans, {this.checked = false, this.taskIndex});

  /// The block's words with all Markdown markers removed.
  String get text => spans.map((s) => s.text).join();

  @override
  String toString() => '${kind.name}: $spans';
}

final RegExp _boldOnlyLine = RegExp(r'^\*\*([^*]+)\*\*:?$');
final RegExp _hashHeadingLine = RegExp(r'^#{1,6}\s+(.+)$');
final RegExp _bulletLine = RegExp(r'^[-*•]\s+(.+)$');
final RegExp _taskLine = RegExp(r'^[-*]\s+\[([ xX])\]\s+(\S.*)$');
final RegExp _numberedLine = RegExp(r'^\d{1,3}[.)]\s+\S');
final RegExp _boldRun = RegExp(r'\*\*(?=\S)(.+?)(?<=\S)\*\*');

List<NoteSpan> _inlineSpans(String line) {
  final spans = <NoteSpan>[];
  var last = 0;
  for (final m in _boldRun.allMatches(line)) {
    if (m.start > last) spans.add(NoteSpan(line.substring(last, m.start)));
    spans.add(NoteSpan(m.group(1)!, bold: true));
    last = m.end;
  }
  if (last < line.length) spans.add(NoteSpan(line.substring(last)));
  return spans;
}

/// Text of a heading line, or null when [line] (already trimmed) is not a heading. A trailing
/// colon is kept so no character is lost.
String? _headingText(String line) {
  final boldOnly = _boldOnlyLine.firstMatch(line);
  if (boldOnly != null) {
    return line.endsWith(':') ? '${boldOnly.group(1)!}:' : boldOnly.group(1)!;
  }
  final hash = _hashHeadingLine.firstMatch(line);
  if (hash != null) {
    return _inlineSpans(hash.group(1)!).map((s) => s.text).join();
  }
  return null;
}

/// Splits a synthesized note into title / heading / bullet / paragraph blocks. Never throws
/// and never drops a word: only the Markdown markers and layout whitespace are removed.
List<NoteBlock> parseNoteMarkdown(String text) {
  final blocks = <NoteBlock>[];
  var sawHeading = false;

  // The block currently being accumulated: its kind, the lines joined into it and, for a task,
  // its box.
  NoteBlockKind? openKind;
  final openLines = <String>[];
  var openChecked = false;
  var tasks = 0;

  void flush() {
    final kind = openKind;
    if (kind == null) return;
    final isTask = kind == NoteBlockKind.task;
    blocks.add(NoteBlock(kind, _inlineSpans(openLines.join(' ')),
        checked: isTask && openChecked, taskIndex: isTask ? tasks++ : null));
    openKind = null;
    openLines.clear();
  }

  for (final rawLine in text.split(RegExp(r'\r\n|\r|\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }

    final heading = _headingText(line);
    if (heading != null) {
      flush();
      blocks.add(NoteBlock(
        sawHeading ? NoteBlockKind.heading : NoteBlockKind.title,
        [NoteSpan(heading)],
      ));
      sawHeading = true;
      continue;
    }

    final task = _taskLine.firstMatch(line);
    if (task != null) {
      flush();
      openKind = NoteBlockKind.task;
      openChecked = task.group(1) != ' ';
      openLines.add(task.group(2)!);
      continue;
    }

    final bullet = _bulletLine.firstMatch(line);
    if (bullet != null) {
      flush();
      openKind = NoteBlockKind.bullet;
      openLines.add(bullet.group(1)!);
      continue;
    }

    // A numbered item keeps its own line (and its number) instead of running into the text
    // before it.
    if (_numberedLine.hasMatch(line)) flush();

    // Plain line: continues an open bullet or paragraph, otherwise starts a paragraph.
    openKind ??= NoteBlockKind.paragraph;
    openLines.add(line);
  }
  flush();
  return blocks;
}

/// The note as one run of plain words (markers and task boxes removed), for compact previews
/// that truncate with an ellipsis.
String plainNotePreview(String text) =>
    parseNoteMarkdown(text).map((b) => b.text).join(' ');

/// [noteText] with the box of task [taskIndex] (counted as [parseNoteMarkdown] counts tasks)
/// set to `[x]` or `[ ]`. Only that one character changes; the text is returned unchanged when
/// the index is out of range or the box is already in the wanted state (a `[X]` stays).
String setTaskChecked(String noteText, int taskIndex, bool checked) {
  if (taskIndex < 0) return noteText;
  var index = 0;
  var lineStart = 0;
  for (final m in RegExp(r'\r\n|\r|\n|$').allMatches(noteText)) {
    final line = noteText.substring(lineStart, m.start);
    final trimmed = line.trim();
    // A heading is never a task line, so the order matches the parser's.
    if (_headingText(trimmed) == null && _taskLine.hasMatch(trimmed)) {
      if (index == taskIndex) {
        final box = lineStart + line.indexOf('[') + 1;
        if ((noteText[box] != ' ') == checked) return noteText;
        return '${noteText.substring(0, box)}${checked ? 'x' : ' '}${noteText.substring(box + 1)}';
      }
      index++;
    }
    if (m.end == noteText.length) break;
    lineStart = m.end;
  }
  return noteText;
}
