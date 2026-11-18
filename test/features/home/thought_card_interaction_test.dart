import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  group('TASK-034 Widget Tests: ThoughtCard Inline Edit & Category Dropdown Reassignment', () {
    testWidgets('1. Tapping edit icon toggles inline text editor and saves changes on submit', (tester) async {
      String? savedText;
      final note = Note(
        rawText: 'Original text',
        correctedText: 'Original text.',
        folder: 'Ideas',
        state: ThoughtState.processed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: note,
              onEdit: (newText) {
                savedText = newText;
              },
            ),
          ),
        ),
      );

      // Verify initial text
      expect(find.text('Original text.'), findsOneWidget);

      // Tap edit button
      final editButton = find.byKey(const Key('edit_text_button'));
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pump();

      // Verify TextField appears with current text
      final textField = find.byKey(const Key('inline_edit_textfield'));
      expect(textField, findsOneWidget);

      // Enter new text and tap Save
      await tester.enterText(textField, 'Updated edited text.');
      await tester.pump();

      final saveButton = find.byKey(const Key('save_edit_button'));
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();

      // Verify callback was called with updated text and UI shows updated text
      expect(savedText, equals('Updated edited text.'));
      expect(find.text('Updated edited text.'), findsOneWidget);
      expect(find.byKey(const Key('inline_edit_textfield')), findsNothing);
    });

    testWidgets('2. FR9.1: Capture cards never expose a folder badge or category picker', (tester) async {
      final note = Note(
        rawText: 'Test note',
        correctedText: 'Test note.',
        folder: 'Ideas',
        state: ThoughtState.processed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: note,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('category_dropdown_button')), findsNothing);
      expect(find.text('Ideas'), findsNothing);
      // The footer offers manual editing only.
      expect(find.byKey(const Key('edit_text_button')), findsOneWidget);
    });

    testWidgets('3. Synthesized card names the session that consumed it', (tester) async {
      final note = Note(
        rawText: 'Clubbed',
        correctedText: 'Clubbed.',
        folder: 'Work',
        state: ThoughtState.synthesized,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: note,
              synthesizedSessionLabel: '#S-02',
            ),
          ),
        ),
      );

      expect(find.textContaining('Synthesized in #S-02'), findsOneWidget);
      expect(find.byKey(const Key('edit_text_button')), findsNothing);
    });
  });
}
