import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/note_list_screen.dart';

void main() {
  group('NoteListScreen Widget Tests', () {
    late NotesRepository fakeRepo;

    setUp(() {
      fakeRepo = NotesRepository();
    });

    Widget createTestWidget(String folder) {
      return ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: NoteListScreen(folder: folder),
        ),
      );
    }

    testWidgets('Renders empty state when folder has no notes', (tester) async {
      await tester.pumpWidget(createTestWidget('Work'));
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('No notes in Work yet.'), findsOneWidget);
    });

    testWidgets('Renders notes filtered by folder with sequence badges', (tester) async {
      final note1 = Note(
        correctedText: 'Work thought 1',
        folder: 'Work',
      );
      final note2 = Note(
        correctedText: 'Work thought 2',
        folder: 'Work',
      );
      final noteOther = Note(
        correctedText: 'Personal idea',
        folder: 'Ideas',
      );

      await fakeRepo.saveNote(note1);
      await fakeRepo.saveNote(note2);
      await fakeRepo.saveNote(noteOther);

      await tester.pumpWidget(createTestWidget('Work'));
      await tester.pumpAndSettle();

      expect(find.text('Work thought 1'), findsOneWidget);
      expect(find.text('Work thought 2'), findsOneWidget);
      expect(find.text('Personal idea'), findsNothing);
      expect(find.byKey(const Key('sequence_badge')), findsNWidgets(2));
    });

    testWidgets('Tapping delete button deletes note and refreshes list', (tester) async {
      final note = Note(
        correctedText: 'Work thought to delete',
        folder: 'Work',
      );
      await fakeRepo.saveNote(note);

      await tester.pumpWidget(createTestWidget('Work'));
      await tester.pumpAndSettle();

      expect(find.text('Work thought to delete'), findsOneWidget);
      expect(find.byKey(const Key('delete_note_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete_note_button')));
      await tester.pumpAndSettle();

      expect(find.text('Work thought to delete'), findsNothing);
      expect(find.text('No notes in Work yet.'), findsOneWidget);
    });
  });
}
