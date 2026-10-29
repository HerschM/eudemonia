import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';

void main() {
  group('TASK-032 Widget Tests: Optimistic Thought Card & Audio Playback', () {
    testWidgets('1. Renders pastel yellow background for enqueued thoughts', (tester) async {
      final enqueuedNote = Note(
        originalAudioPath: '/data/audio/recording_1.wav',
        state: ThoughtState.enqueued,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: enqueuedNote,
            ),
          ),
        ),
      );

      // Verify pastel yellow container background
      final containerFinder = find.byType(Container).first;
      final Container container = tester.widget(containerFinder);
      final BoxDecoration decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFEF3C7)); // Light pastel yellow
      expect(find.text('⏳ Enqueued'), findsOneWidget);
    });

    testWidgets('2. Tapping play icon toggles playback state without navigating away', (tester) async {
      bool playToggled = false;
      final note = Note(
        originalAudioPath: '/data/audio/recording_1.wav',
        state: ThoughtState.enqueued,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: note,
              isPlaying: false,
              onPlayAudio: () {
                playToggled = true;
              },
            ),
          ),
        ),
      );

      final playButton = find.byKey(const Key('play_audio_button'));
      expect(playButton, findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

      await tester.tap(playButton);
      await tester.pump();

      expect(playToggled, isTrue);
    });

    testWidgets('3. Shimmer sub-text renders while state is enqueued', (tester) async {
      final enqueuedNote = Note(
        originalAudioPath: '/data/audio/recording_1.wav',
        state: ThoughtState.enqueued,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThoughtCard(
              note: enqueuedNote,
            ),
          ),
        ),
      );

      expect(find.text('Transcribing & organizing speech...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
