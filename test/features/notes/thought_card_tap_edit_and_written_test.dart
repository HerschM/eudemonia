import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    Note note, {
    ValueChanged<String>? onEdit,
    ValueChanged<String>? onCopy,
    VoidCallback? onTap,
    VoidCallback? onPlay,
    bool highlighted = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ThoughtCard(
          note: note,
          sequenceNumber: 12,
          onEdit: onEdit,
          onCopy: onCopy,
          onTap: onTap,
          onPlayAudio: onPlay,
          onDelete: () {},
          highlighted: highlighted,
        ),
      ),
    ));
  }

  group('tap the text to edit (decision B, 2026-11-28)', () {
    testWidgets('a tap on the text of a processed thought opens the inline editor, like Edit', (tester) async {
      final edits = <String>[];
      await pumpCard(tester, Note(correctedText: 'Water the plants.', isRead: true), onEdit: edits.add);
      expect(find.byKey(const Key('inline_edit_textfield')), findsNothing);
      expect(find.byKey(const Key('edit_text_button')), findsOneWidget);

      await tester.tap(find.text('Water the plants.'));
      await tester.pump();

      expect(find.byKey(const Key('inline_edit_textfield')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('inline_edit_textfield'))).controller!.text, 'Water the plants.');
      await tester.enterText(find.byKey(const Key('inline_edit_textfield')), 'Water the ferns.');
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pump();
      expect(edits, ['Water the ferns.'], reason: 'saved through the same onEdit path as the Edit button');
      expect(find.text('Water the ferns.'), findsOneWidget);
    });

    testWidgets('the Edit button still works and gives the same editor', (tester) async {
      await pumpCard(tester, Note(correctedText: 'Water the plants.'), onEdit: (_) {});
      await tester.tap(find.byKey(const Key('edit_text_button')));
      await tester.pump();
      expect(find.byKey(const Key('inline_edit_textfield')), findsOneWidget);
    });

    testWidgets('the tap still counts as a tap on the card (it marks the thought read)', (tester) async {
      var taps = 0;
      await pumpCard(tester, Note(correctedText: 'Unseen.'), onEdit: (_) {}, onTap: () => taps++);
      await tester.tap(find.text('Unseen.'));
      await tester.pump();
      expect(taps, 1);
      expect(find.byKey(const Key('inline_edit_textfield')), findsOneWidget);
    });

    testWidgets('a long press on the text still copies and does not edit', (tester) async {
      final copied = <String>[];
      await pumpCard(tester, Note(correctedText: 'Hold me.'), onEdit: (_) {}, onCopy: copied.add);
      await tester.longPress(find.text('Hold me.'));
      await tester.pump();
      expect(copied, ['Hold me.']);
      expect(find.byKey(const Key('inline_edit_textfield')), findsNothing);
    });

    testWidgets('a tap elsewhere on the card keeps its behaviour: it is only a card tap', (tester) async {
      var taps = 0;
      await pumpCard(tester, Note(correctedText: 'Elsewhere.', createdAt: DateTime(2026, 11, 28, 9, 5)),
          onEdit: (_) {}, onTap: () => taps++);
      await tester.tap(find.byKey(const Key('sequence_badge')));
      await tester.pump();
      expect(taps, 1);
      expect(find.byKey(const Key('inline_edit_textfield')), findsNothing);
    });

    testWidgets('only where the Edit button exists: not for a synthesized or failed thought', (tester) async {
      for (final note in [
        Note(correctedText: 'Clubbed.', state: ThoughtState.synthesized),
        Note(correctedText: '', state: ThoughtState.failed, failureReason: 'Network timeout.'),
        Note(correctedText: '', state: ThoughtState.failed, failureReason: silentRecordingMessage),
      ]) {
        await pumpCard(tester, note, onEdit: (_) {});
        expect(find.byKey(const Key('edit_text_button')), findsNothing);
        for (final text in ['Clubbed.', 'Network timeout.', silentRecordingMessage]) {
          if (find.text(text).evaluate().isNotEmpty) await tester.tap(find.text(text));
        }
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const Key('inline_edit_textfield')), findsNothing, reason: '${note.state}');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('while editing, a tap in the field does not restart the editor', (tester) async {
      await pumpCard(tester, Note(correctedText: 'Draft.'), onEdit: (_) {});
      await tester.tap(find.text('Draft.'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('inline_edit_textfield')), 'Draft, changed');
      await tester.tap(find.byKey(const Key('inline_edit_textfield')));
      await tester.pump();
      expect(find.text('Draft, changed'), findsOneWidget);
      expect(find.byKey(const Key('inline_edit_textfield')), findsOneWidget);
    });
  });

  group('written note marker (decision C, 2026-11-28)', () {
    testWidgets('a written thought shows a pen, not a play control, and no audio is assumed', (tester) async {
      var played = 0;
      await pumpCard(tester, Note(correctedText: 'Typed.', isWritten: true, isRead: true), onPlay: () => played++);

      expect(find.byKey(const Key('written_note_marker')), findsOneWidget);
      expect(find.byKey(const Key('play_audio_button')), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byTooltip('Written note'), findsOneWidget);
      expect(
        find.ancestor(of: find.byKey(const Key('written_note_marker')), matching: find.byType(IconButton)),
        findsNothing,
        reason: 'the pen is not a button',
      );
      await tester.tap(find.byKey(const Key('written_note_marker')));
      await tester.pump();
      expect(played, 0);
    });

    testWidgets('the pen is announced as Written note', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, Note(correctedText: 'Typed.', isWritten: true));
      expect(find.bySemanticsLabel(RegExp('Written note')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a voice thought keeps its play control and shows no pen', (tester) async {
      await pumpCard(tester, Note(correctedText: 'Spoken.', originalAudioPath: '/a.wav'), onPlay: () {});
      expect(find.byKey(const Key('play_audio_button')), findsOneWidget);
      expect(find.byKey(const Key('written_note_marker')), findsNothing);
    });

    testWidgets('a written thought is edited, copied and deleted like any other (the text tap works)', (tester) async {
      final edits = <String>[];
      await pumpCard(tester, Note(correctedText: 'Typed.', isWritten: true), onEdit: edits.add, onCopy: (_) {});
      await tester.tap(find.text('Typed.'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('inline_edit_textfield')), 'Typed, edited.');
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pump();
      expect(edits, ['Typed, edited.']);
      expect(find.byKey(const Key('delete_note_button')), findsOneWidget);
      expect(find.byKey(const Key('thought_copy_button')), findsOneWidget);
    });

    testWidgets('360 dp: sequence number, pen, unread dot, copy and delete fit on one header row', (tester) async {
      await pumpCard(tester, Note(correctedText: 'Typed.', isWritten: true), onCopy: (_) {}, onEdit: (_) {});
      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byKey(const Key('header_row')));
      for (final key in ['sequence_badge', 'written_note_marker', 'unread_dot', 'thought_copy_button', 'delete_note_button']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.right, lessThanOrEqualTo(header.right), reason: key);
        expect(r.left, greaterThanOrEqualTo(header.left), reason: key);
      }
      expect(tester.getRect(find.byKey(const Key('sequence_badge'))).right,
          lessThanOrEqualTo(tester.getRect(find.byKey(const Key('written_note_marker'))).left));
      expect(tester.getRect(find.byKey(const Key('written_note_marker'))).right,
          lessThanOrEqualTo(tester.getRect(find.byKey(const Key('unread_dot'))).left));
    });
  });

  group('highlight (decision D)', () {
    testWidgets('a highlighted card glows; a normal one does not', (tester) async {
      BoxDecoration decoration() => tester
          .widget<Container>(find
              .ancestor(of: find.byKey(const Key('header_row')), matching: find.byType(Container))
              .last)
          .decoration! as BoxDecoration;
      await pumpCard(tester, Note(correctedText: 'Here.'), highlighted: true);
      expect(decoration().boxShadow, isNotEmpty);
      await pumpCard(tester, Note(correctedText: 'Here.'));
      expect(decoration().boxShadow, anyOf(isNull, isEmpty));
    });
  });
}
