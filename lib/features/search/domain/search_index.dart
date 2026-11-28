import 'package:flutter/painting.dart' show TextRange;
import 'package:eudemonia/core/formatting/thought_timestamp.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';

/// The screen a search result belongs to.
enum SearchSource { capture, synthesis }

/// One search hit: what to open ([noteId] for a thought, [clusterId] for a synthesis note), the
/// line it is listed under, and a [snippet] of its text with the [matches] (ranges into
/// [snippet]) to draw in bold.
class SearchResult {
  final SearchSource source;
  final int? noteId;
  final String? clusterId;
  final String title;
  final DateTime date;
  final String snippet;
  final List<TextRange> matches;

  const SearchResult({
    required this.source,
    this.noteId,
    this.clusterId,
    required this.title,
    required this.date,
    required this.snippet,
    required this.matches,
  });

  /// The id as the result row's key spells it (`capture_12`, `synthesis_cluster_ab`).
  String get rowId => source == SearchSource.capture ? 'capture_$noteId' : 'synthesis_$clusterId';
}

/// Longest stretch of text a snippet shows, and how much of it may come before the first match.
const int _snippetLength = 120;
const int _snippetLead = 30;

/// The thoughts and synthesis notes that contain every whitespace-separated word of [query]
/// (case-insensitive), newest first. A thought is searched by its text (a thought still being
/// transcribed has none and never matches); a note by its title, its plain text and its folder name.
List<SearchResult> searchThoughtsAndNotes(
  String query, {
  required List<Note> thoughts,
  required List<SynthesisCluster> notes,
}) {
  final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final patterns = [for (final w in words) RegExp(RegExp.escape(w), caseSensitive: false)];
  bool containsAll(String haystack) => patterns.every((p) => p.hasMatch(haystack));

  final results = <SearchResult>[];
  for (final thought in thoughts) {
    final text = _collapse(thought.correctedText.trim().isNotEmpty ? thought.correctedText : thought.rawText);
    if (text.isEmpty || !containsAll(text)) continue;
    final date = thought.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final number = thought.dailySequenceNumber;
    final stamp = formatThoughtTimestamp(date);
    final snippet = _snippet(text, patterns);
    results.add(SearchResult(
      source: SearchSource.capture,
      noteId: thought.id,
      title: number == null ? stamp : '#${number.toString().padLeft(2, '0')} · $stamp',
      date: date,
      snippet: snippet.text,
      matches: snippet.matches,
    ));
  }
  for (final note in notes) {
    final title = noteListTitle(note.synthesizedContent);
    final plain = _collapse(noteTextForClipboard('', note.synthesizedContent));
    if (!containsAll('$title\n$plain\n${note.folder}')) continue;
    final snippet = _snippet(plain, patterns);
    results.add(SearchResult(
      source: SearchSource.synthesis,
      clusterId: note.clusterId,
      title: '${note.sequenceNumber} · $title',
      date: note.sessionStart,
      snippet: snippet.text,
      matches: snippet.matches,
    ));
  }
  // Stable for equal dates: thoughts first, in the order they were given.
  final order = <SearchResult, int>{for (var i = 0; i < results.length; i++) results[i]: i};
  results.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : order[a]!.compareTo(order[b]!);
  });
  return results;
}

String _collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

class _Snippet {
  final String text;
  final List<TextRange> matches;
  const _Snippet(this.text, this.matches);
}

/// A stretch of [text] around the earliest match of any pattern, with `…` where it was cut, and
/// every match inside it (overlapping and touching ones joined) as ranges into the returned text.
/// Without a match in [text] (a note found by its folder name) the stretch is its start.
_Snippet _snippet(String text, List<RegExp> patterns) {
  final found = <TextRange>[
    for (final p in patterns)
      for (final m in p.allMatches(text)) TextRange(start: m.start, end: m.end),
  ]..sort((a, b) => a.start.compareTo(b.start));

  var start = found.isEmpty || found.first.start <= _snippetLead ? 0 : found.first.start - _snippetLead;
  if (start > 0) {
    // Begin on a whole word when one starts shortly before the match.
    final space = text.indexOf(' ', start);
    if (space != -1 && space < found.first.start) start = space + 1;
  }
  var end = start + _snippetLength;
  if (found.isNotEmpty && end < found.first.end) end = found.first.end;
  if (end > text.length) end = text.length;

  final lead = start > 0 ? '…' : '';
  final tail = end < text.length ? '…' : '';
  final ranges = <TextRange>[];
  for (final m in found) {
    if (m.end <= start || m.start >= end) continue;
    final from = (m.start < start ? start : m.start) - start + lead.length;
    final to = (m.end > end ? end : m.end) - start + lead.length;
    if (ranges.isNotEmpty && from <= ranges.last.end) {
      if (to > ranges.last.end) ranges[ranges.length - 1] = TextRange(start: ranges.last.start, end: to);
    } else {
      ranges.add(TextRange(start: from, end: to));
    }
  }
  return _Snippet('$lead${text.substring(start, end)}$tail', ranges);
}
