import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/search/domain/search_index.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

Note thought(int id, String text, {DateTime? at, int? number, String raw = ''}) => Note(
      correctedText: text,
      rawText: raw,
      createdAt: at ?? DateTime(2026, 11, 20, 14, 37),
      dailySequenceNumber: number ?? id,
    )..id = id;

SynthesisCluster note(
  String id,
  String content, {
  String folder = 'Ideas',
  String number = '#S-01',
  DateTime? start,
}) {
  final at = start ?? DateTime(2026, 11, 21, 9, 5);
  return SynthesisCluster(
    clusterId: id,
    sequenceNumber: number,
    folder: folder,
    synthesizedContent: content,
    sessionStart: at,
    sessionEnd: at.add(const Duration(minutes: 5)),
    sessionDuration: const Duration(minutes: 5),
    originNotes: const [],
  );
}

String marked(SearchResult r) => r.matches.map((m) => r.snippet.substring(m.start, m.end)).join('|');

void main() {
  group('searchThoughtsAndNotes', () {
    test('an empty or blank query returns nothing', () {
      final thoughts = [thought(1, 'Buy milk')];
      expect(searchThoughtsAndNotes('', thoughts: thoughts, notes: const []), isEmpty);
      expect(searchThoughtsAndNotes('   ', thoughts: thoughts, notes: const []), isEmpty);
    });

    test('every word of the query must occur, in any order, ignoring case', () {
      final thoughts = [
        thought(1, 'Buy MILK and eggs'),
        thought(2, 'Buy bread'),
        thought(3, 'milk only'),
      ];
      final results = searchThoughtsAndNotes('milk  buy', thoughts: thoughts, notes: const []);
      expect(results.map((r) => r.noteId), [1]);
      expect(searchThoughtsAndNotes('MILK', thoughts: thoughts, notes: const []).map((r) => r.noteId).toSet(), {1, 3});
    });

    test('thoughts without text yet never match, and raw text stands in for a missing corrected text', () {
      final thoughts = [
        thought(1, ''),
        thought(2, '   '),
        thought(3, '', raw: 'raw words here'),
      ];
      expect(searchThoughtsAndNotes('words', thoughts: thoughts, notes: const []).map((r) => r.noteId), [3]);
      expect(searchThoughtsAndNotes('s', thoughts: [thought(1, ''), thought(2, '  ')], notes: const []), isEmpty);
    });

    test('a note matches on its title, its plain text and its folder name', () {
      final notes = [
        note('a', '# Garden plan\n\n- **Plant** tomatoes', folder: 'Home'),
        note('b', '# Other\n\nnothing relevant', folder: 'Garden'),
        note('c', '# Other\n\nnothing relevant', folder: 'Work'),
      ];
      final byTitle = searchThoughtsAndNotes('garden', thoughts: const [], notes: notes);
      expect(byTitle.map((r) => r.clusterId).toSet(), {'a', 'b'});
      // Words may be spread over title, text and folder: one note answers "garden tomatoes home".
      expect(searchThoughtsAndNotes('garden tomatoes home', thoughts: const [], notes: notes).map((r) => r.clusterId),
          ['a']);
      // The plain text has its markers removed: a search for bold text finds it.
      expect(searchThoughtsAndNotes('plant tomatoes', thoughts: const [], notes: notes).map((r) => r.clusterId), ['a']);
      expect(searchThoughtsAndNotes('**plant', thoughts: const [], notes: notes), isEmpty);
    });

    test('results are newest first across thoughts and notes', () {
      final results = searchThoughtsAndNotes(
        'idea',
        thoughts: [
          thought(1, 'old idea', at: DateTime(2026, 11, 1)),
          thought(2, 'new idea', at: DateTime(2026, 11, 25)),
        ],
        notes: [
          note('n1', '# An idea', start: DateTime(2026, 11, 10)),
          note('n2', '# Another idea', start: DateTime(2026, 11, 27)),
        ],
      );
      expect(results.map((r) => r.source == SearchSource.capture ? 'c${r.noteId}' : 's${r.clusterId}'),
          ['sn2', 'c2', 'sn1', 'c1']);
    });

    test('each result names its source, the id to open, a title line and the date', () {
      final results = searchThoughtsAndNotes(
        'tomatoes',
        thoughts: [thought(7, 'Tomatoes need sun', at: DateTime(2026, 11, 20, 14, 37), number: 3)],
        notes: [note('n1', '# Garden plan\n\ntomatoes', number: '#S-02', start: DateTime(2026, 11, 21, 9, 5))],
      );
      final s = results.first;
      expect(s.source, SearchSource.synthesis);
      expect(s.clusterId, 'n1');
      expect(s.noteId, isNull);
      expect(s.title, '#S-02 · Garden plan');
      expect(s.date, DateTime(2026, 11, 21, 9, 5));
      final c = results.last;
      expect(c.source, SearchSource.capture);
      expect(c.noteId, 7);
      expect(c.clusterId, isNull);
      expect(c.title, '#03 · 20/11  02:37 PM');
      expect(c.date, DateTime(2026, 11, 20, 14, 37));
    });

    test('the snippet marks every matched word, keeping the original letter case', () {
      final r = searchThoughtsAndNotes('milk EGGS', thoughts: [thought(1, 'Buy Milk and eggs, more milk')], notes: const [])
          .single;
      expect(r.snippet, 'Buy Milk and eggs, more milk');
      expect(marked(r), 'Milk|eggs|milk');
      expect(r.matches.first, const TextRange(start: 4, end: 8));
    });

    test('a long text is cut around the first match with an ellipsis, and the marks follow the cut', () {
      final text = '${List.filled(40, 'filler').join(' ')} needle ${List.filled(40, 'filler').join(' ')}';
      final r = searchThoughtsAndNotes('needle', thoughts: [thought(1, text)], notes: const []).single;
      expect(r.snippet.startsWith('…'), isTrue);
      expect(r.snippet.endsWith('…'), isTrue);
      expect(r.snippet.length, lessThan(160));
      expect(marked(r), 'needle');
    });

    test('a match at the very start has no leading ellipsis', () {
      final text = 'needle ${List.filled(60, 'filler').join(' ')}';
      final r = searchThoughtsAndNotes('needle', thoughts: [thought(1, text)], notes: const []).single;
      expect(r.snippet.startsWith('needle'), isTrue);
      expect(r.snippet.endsWith('…'), isTrue);
      expect(r.matches.single, const TextRange(start: 0, end: 6));
    });

    test('a note matched only through its folder shows the start of its text with nothing marked', () {
      final r = searchThoughtsAndNotes('journal', thoughts: const [], notes: [note('a', '# Day\n\nWent for a walk', folder: 'Journal')])
          .single;
      expect(r.matches, isEmpty);
      expect(r.snippet, contains('Went for a walk'));
    });

    test('line breaks in a text become single spaces in the snippet', () {
      final r = searchThoughtsAndNotes('b', thoughts: [thought(1, 'a\n\nb   c')], notes: const []).single;
      expect(r.snippet, 'a b c');
    });

    test('a query with regex characters is searched literally', () {
      final r = searchThoughtsAndNotes('(a+', thoughts: [thought(1, 'call (a+b) later'), thought(2, 'aaa')], notes: const []);
      expect(r.map((x) => x.noteId), [1]);
    });
  });
}
