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

    testWidgets('2. Tapping category badge opens category dropdown picker', (tester) async {
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

      // Category badge exists
      final dropdownButton = find.byKey(const Key('category_dropdown_button'));
      expect(dropdownButton, findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);

      // Tap badge to open popup menu
      await tester.tap(dropdownButton);
      await tester.pumpAndSettle();

      // Verify dropdown options are displayed
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
    });

    testWidgets('3. Selecting new category invokes update callback and updates pill label', (tester) async {
      String? selectedFolder;
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
              onCategoryChanged: (newCat) {
                selectedFolder = newCat;
              },
            ),
          ),
        ),
      );

      // Tap badge
      final dropdownButton = find.byKey(const Key('category_dropdown_button'));
      await tester.tap(dropdownButton);
      await tester.pumpAndSettle();

      // Tap 'Work' item in popup menu
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      // Verify callback received 'Work' and pill label now displays 'Work'
      expect(selectedFolder, equals('Work'));
      expect(find.text('Work'), findsOneWidget);
    });
  });
}
