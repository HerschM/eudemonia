import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  group('TASK-033 Widget Tests: Processed Blue & Failed Red Card States', () {
    testWidgets('1. Processed thought card displays soft blue background and folder badge', (tester) async {
      final processedNote = Note(
        originalAudioPath: '/data/audio/recording_1.wav',
        rawText: 'Schedule team sync for next week',
        correctedText: 'Schedule team sync for next week.',
        folder: 'Work',
        state: ThoughtState.processed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: processedNote,
            ),
          ),
        ),
      );

      // Verify soft blue container background (Color(0xFFDBEAFE))
      final containerFinder = find.byType(Container).first;
      final Container container = tester.widget(containerFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFDBEAFE));

      // Verify folder badge is visible
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Schedule team sync for next week.'), findsOneWidget);
    });

    testWidgets('2. Failed thought card displays soft red background and Retry button', (tester) async {
      final failedNote = Note(
        originalAudioPath: '/data/audio/recording_failed.wav',
        state: ThoughtState.failed,
        failureReason: 'Speech recognition engine timeout after 30s.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: failedNote,
            ),
          ),
        ),
      );

      // Verify soft red container background (Color(0xFFFEE2E2))
      final containerFinder = find.byType(Container).first;
      final Container container = tester.widget(containerFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFEE2E2));

      // Verify failed badge and error reason text
      expect(find.text('⚠️ Failed'), findsOneWidget);
      expect(find.text('Speech recognition engine timeout after 30s.'), findsOneWidget);

      // Verify Retry button is displayed
      expect(find.byKey(const Key('retry_button')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('3. Tapping Retry fires retry callback', (tester) async {
      bool retryInvoked = false;
      final failedNote = Note(
        originalAudioPath: '/data/audio/recording_failed.wav',
        state: ThoughtState.failed,
        failureReason: 'Speech recognition engine timeout after 30s.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: failedNote,
              onRetry: () {
                retryInvoked = true;
              },
            ),
          ),
        ),
      );

      final retryButton = find.byKey(const Key('retry_button'));
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      expect(retryInvoked, isTrue);
    });
  });
}
