import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    Note note, {
    ValueChanged<String>? onCopy,
    VoidCallback? onLongPress,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ThoughtCard(
          note: note,
          sequenceNumber: 4,
          onCopy: onCopy,
          onLongPress: onLongPress,
          onDelete: () {},
          onEdit: (_) {},
        ),
      ),
    ));
  }

  group('ThoughtCard copy control', () {
    testWidgets('a processed thought shows a Copy button that hands over its text', (tester) async {
      final copied = <String>[];
      await pumpCard(tester, Note(correctedText: 'Water the plants.', state: ThoughtState.processed), onCopy: copied.add);

      expect(find.byKey(const Key('thought_copy_button')), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      await tester.tap(find.byKey(const Key('thought_copy_button')));
      expect(copied, ['Water the plants.']);
    });

    testWidgets('a synthesized thought can be copied too', (tester) async {
      final copied = <String>[];
      await pumpCard(tester, Note(correctedText: 'Clubbed.', state: ThoughtState.synthesized), onCopy: copied.add);
      await tester.tap(find.byKey(const Key('thought_copy_button')));
      expect(copied, ['Clubbed.']);
    });

    testWidgets('long press on the card copies the same text', (tester) async {
      final copied = <String>[];
      await pumpCard(tester, Note(correctedText: 'Long pressed.', state: ThoughtState.processed), onCopy: copied.add);
      await tester.longPress(find.text('Long pressed.'));
      expect(copied, ['Long pressed.']);
    });

    testWidgets('the edited text, not the stale one, is what gets copied', (tester) async {
      final copied = <String>[];
      await pumpCard(tester, Note(correctedText: 'Before.', state: ThoughtState.processed), onCopy: copied.add);
      await tester.tap(find.byKey(const Key('edit_text_button')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('inline_edit_textfield')), 'After.');
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('thought_copy_button')));
      expect(copied, ['After.']);
    });

    testWidgets('nothing to copy while transcribing, after a failure or for a silent recording', (tester) async {
      for (final note in [
        Note(state: ThoughtState.enqueued),
        Note(state: ThoughtState.failed, failureReason: 'Network timeout.'),
        Note(state: ThoughtState.failed, failureReason: silentRecordingMessage),
      ]) {
        await pumpCard(tester, note, onCopy: (_) {});
        expect(find.byKey(const Key('thought_copy_button')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('no Copy button without a handler, and an explicit onLongPress keeps working', (tester) async {
      var longPresses = 0;
      await pumpCard(tester, Note(correctedText: 'Plain.', state: ThoughtState.processed), onLongPress: () => longPresses++);
      expect(find.byKey(const Key('thought_copy_button')), findsNothing);
      await tester.longPress(find.text('Plain.'));
      expect(longPresses, 1);
    });
  });
}
