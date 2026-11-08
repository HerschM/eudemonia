import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  group('Daily Sequence Numbering (FR9.4 & FR9.5)', () {
    late NotesRepository repository;

    setUp(() {
      repository = NotesRepository(); // in-memory
    });

    test('Notes assigned immutable daily sequence numbers and preserve gaps on deletion', () async {
      final today = DateTime(2026, 11, 8, 10, 0);

      final note1 = Note(rawText: 'First', correctedText: 'First', createdAt: today);
      final note2 = Note(rawText: 'Second', correctedText: 'Second', createdAt: today);
      final note3 = Note(rawText: 'Third', correctedText: 'Third', createdAt: today);

      await repository.saveNote(note1);
      await repository.saveNote(note2);
      await repository.saveNote(note3);

      expect(note1.dailySequenceNumber, 1);
      expect(note2.dailySequenceNumber, 2);
      expect(note3.dailySequenceNumber, 3);

      // FR9.5: Deleting note #2 leaves note #1 and #3 intact (gaps preserved)
      await repository.deleteNote(note2.id);

      final remaining = await repository.getAllNotes();
      expect(remaining.length, 2);
      expect(remaining.any((n) => n.dailySequenceNumber == 1), isTrue);
      expect(remaining.any((n) => n.dailySequenceNumber == 3), isTrue);
      expect(remaining.any((n) => n.dailySequenceNumber == 2), isFalse);

      // Adding note #4 continues from max sequence (4)
      final note4 = Note(rawText: 'Fourth', correctedText: 'Fourth', createdAt: today);
      await repository.saveNote(note4);
      expect(note4.dailySequenceNumber, 4);
    });

    test('Daily sequence numbers reset on a new calendar day (FR9.4)', () async {
      final day1 = DateTime(2026, 11, 8, 22, 0);
      final day2 = DateTime(2026, 11, 9, 8, 0);

      final noteDay1 = Note(rawText: 'Day 1 note', correctedText: 'Day 1 note', createdAt: day1);
      await repository.saveNote(noteDay1);
      expect(noteDay1.dailySequenceNumber, 1);

      final noteDay2 = Note(rawText: 'Day 2 note', correctedText: 'Day 2 note', createdAt: day2);
      await repository.saveNote(noteDay2);
      expect(noteDay2.dailySequenceNumber, 1); // Reset to 1 on new day
    });
  });

  group('ThoughtCard Layout & Narrow Viewport Overflow Guarantee', () {
    testWidgets('Unread card on 360dp narrow viewport renders with strict header order and ZERO overflow', (tester) async {
      // Set 360dp narrow phone viewport
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool deleted = false;
      final unreadNote = Note(
        originalAudioPath: '/path/to/recording_116.wav',
        rawText: 'Test transcript for note 116',
        correctedText: 'Test transcript for note 116 with significant text length to test layout',
        folder: 'Uncategorized',
        createdAt: DateTime(2026, 11, 8, 9, 42),
        dailySequenceNumber: 116,
        state: ThoughtState.processed,
        isRead: false,
      )..id = 116;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ThoughtCard(
                note: unreadNote,
                sequenceNumber: unreadNote.dailySequenceNumber,
                onDelete: () => deleted = true,
              ),
            ),
          ),
        ),
      );

      // Zero RenderFlex framework assertions
      expect(tester.takeException(), isNull);

      // Verify strict header order: [# Number] -> [Play Button] -> [Unread Dot] -> [Delete Button]
      final badgeFinder = find.byKey(const Key('sequence_badge'));
      final playFinder = find.byKey(const Key('play_audio_button'));
      final unreadDotFinder = find.byKey(const Key('unread_dot'));
      final deleteFinder = find.byKey(const Key('delete_note_button'));

      expect(badgeFinder, findsOneWidget);
      expect(playFinder, findsOneWidget);
      expect(unreadDotFinder, findsOneWidget);
      expect(deleteFinder, findsOneWidget);

      final badgePos = tester.getTopLeft(badgeFinder);
      final playPos = tester.getTopLeft(playFinder);
      final unreadDotPos = tester.getTopLeft(unreadDotFinder);
      final deletePos = tester.getTopLeft(deleteFinder);

      expect(badgePos.dx, lessThan(playPos.dx), reason: 'Sequence badge must precede Play button');
      expect(playPos.dx, lessThan(unreadDotPos.dx), reason: 'Play button must precede Unread dot');
      expect(unreadDotPos.dx, lessThan(deletePos.dx), reason: 'Unread dot must precede Delete button');

      // Verify delete button is clickable
      await tester.tap(deleteFinder);
      expect(deleted, isTrue);

      // Verify formatted timestamp at footer: DD/MM  HH:MM AM/PM
      expect(find.text('08/11  09:42 AM'), findsOneWidget);

      // Verify category dropdown in footer
      expect(find.byKey(const Key('category_dropdown_button')), findsOneWidget);

      // Verify edit button in footer
      expect(find.byKey(const Key('edit_text_button')), findsOneWidget);
    });

    testWidgets('Failed card uniformly renders delete button in header and retry in footer', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool deleted = false;
      bool retried = false;

      final failedNote = Note(
        originalAudioPath: '/path/to/failed.wav',
        rawText: '',
        correctedText: '',
        folder: 'Uncategorized',
        createdAt: DateTime(2026, 11, 8, 7, 40),
        dailySequenceNumber: 2,
        state: ThoughtState.failed,
        failureReason: 'No speech detected in audio recording.',
        isRead: true,
      )..id = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ThoughtCard(
                note: failedNote,
                sequenceNumber: failedNote.dailySequenceNumber,
                onDelete: () => deleted = true,
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // Verify delete button exists and works on failed note
      final deleteFinder = find.byKey(const Key('delete_note_button'));
      expect(deleteFinder, findsOneWidget);
      await tester.tap(deleteFinder);
      expect(deleted, isTrue);

      // Verify retry button exists and works in footer
      final retryFinder = find.byKey(const Key('retry_button'));
      expect(retryFinder, findsOneWidget);
      await tester.tap(retryFinder);
      expect(retried, isTrue);
    });
  });
}
