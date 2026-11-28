import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/capture/presentation/thought_delete_wording.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

SynthesisOriginNote _origin(int id) => SynthesisOriginNote(
      id: id,
      formattedSequence: '#0$id',
      cleanedText: 'thought $id',
      timestamp: DateTime(2026, 11, 27, 9),
    );

SynthesisCluster _session({
  required List<int> thoughts,
  String label = '#S-02',
  String content = '# Garden plans\n\n- plant beans',
  String style = defaultNoteStyleId,
  DateTime? start,
}) =>
    SynthesisCluster(
      clusterId: 'c1',
      sequenceNumber: label,
      folder: 'Ideas',
      synthesizedContent: content,
      sessionStart: start ?? DateTime(2026, 11, 27, 9),
      sessionEnd: DateTime(2026, 11, 27, 10),
      sessionDuration: const Duration(hours: 1),
      originNotes: [for (final id in thoughts) _origin(id)],
      appliedStyleId: style,
    );

void main() {
  final created = DateTime(2026, 11, 27, 9, 5);

  group('deleteThoughtQuestion', () {
    test('names the thought by the number its card shows', () {
      expect(deleteThoughtQuestion(3), 'Delete thought #03?');
      expect(deleteThoughtQuestion(12), 'Delete thought #12?');
    });

    test('a thought without a number is just this thought', () {
      expect(deleteThoughtQuestion(null), 'Delete this thought?');
    });
  });

  group('describeThoughtDeleteConsequence', () {
    test('a thought no note was written from has no consequence', () {
      expect(describeThoughtDeleteConsequence(session: null, noteId: 1, thoughtCreatedAt: created), isNull);
    });

    test('the only thought of a note: the note is deleted too', () {
      expect(
        describeThoughtDeleteConsequence(session: _session(thoughts: [1]), noteId: 1, thoughtCreatedAt: created),
        'Note #S-02 "Garden plans" will be deleted too.',
      );
    });

    test('a note with other thoughts is rewritten without this one', () {
      expect(
        describeThoughtDeleteConsequence(session: _session(thoughts: [1, 2]), noteId: 1, thoughtCreatedAt: created),
        'Note #S-02 "Garden plans" will be rewritten without this thought.',
      );
    });

    test('a note edited by hand keeps its text: only the list of its thoughts shrinks', () {
      expect(
        describeThoughtDeleteConsequence(
          session: _session(thoughts: [1, 2], style: manualStyleId),
          noteId: 1,
          thoughtCreatedAt: created,
        ),
        'Note #S-02 "Garden plans" was edited by hand, so its text stays as it is; this thought is only removed from its source thoughts.',
      );
    });

    test('a hand-edited note that held only this thought is still deleted', () {
      expect(
        describeThoughtDeleteConsequence(
          session: _session(thoughts: [1], style: manualStyleId),
          noteId: 1,
          thoughtCreatedAt: created,
        ),
        'Note #S-02 "Garden plans" will be deleted too.',
      );
    });

    test('a note of another day carries its date, like the card badge', () {
      final text = describeThoughtDeleteConsequence(
        session: _session(thoughts: [1, 2], start: DateTime(2026, 11, 26, 23, 50)),
        noteId: 1,
        thoughtCreatedAt: created,
      );
      expect(text, 'Note #S-02 · 26/11 "Garden plans" will be rewritten without this thought.');
    });

    test('a note without a title block is named by its first words', () {
      final text = describeThoughtDeleteConsequence(
        session: _session(thoughts: [1], content: 'Buy seeds and soil'),
        noteId: 1,
        thoughtCreatedAt: created,
      );
      expect(text, 'Note #S-02 "Buy seeds and soil" will be deleted too.');
    });
  });
}
