import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/audio_playback_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TASK-032 Unit Tests: Note Model Lifecycle & Audio Playback Controller', () {
    test('1. Note model instantiation supports ThoughtState.enqueued with audioFilePath', () {
      final note = Note(
        originalAudioPath: '/data/user/0/com.eudemonia/queue/thought_123.wav',
        rawText: '',
        correctedText: '',
        folder: 'Uncategorized',
        state: ThoughtState.enqueued,
      );

      expect(note.state, ThoughtState.enqueued);
      expect(note.originalAudioPath, '/data/user/0/com.eudemonia/queue/thought_123.wav');
      expect(note.createdAt, isNotNull);
      expect(note.isRead, isFalse);
    });

    test('2. Audio player controller toggles play and pause on local file path', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(audioPlaybackControllerProvider.notifier);

      expect(controller.isPlaying, isFalse);
      expect(controller.currentAudioPath, isNull);

      // Play audio path
      await controller.play('/data/user/0/com.eudemonia/queue/thought_123.wav');
      expect(controller.isPlaying, isTrue);
      expect(controller.currentAudioPath, '/data/user/0/com.eudemonia/queue/thought_123.wav');

      // Toggling play on the same path pauses it
      await controller.play('/data/user/0/com.eudemonia/queue/thought_123.wav');
      expect(controller.isPlaying, isFalse);

      // Calling play again resumes it
      await controller.play('/data/user/0/com.eudemonia/queue/thought_123.wav');
      expect(controller.isPlaying, isTrue);

      // Explicit pause
      await controller.pause();
      expect(controller.isPlaying, isFalse);

      // Stop resets path
      await controller.stop();
      expect(controller.isPlaying, isFalse);
      expect(controller.currentAudioPath, isNull);
    });
  });
}
