import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/home_screen.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/audio_playback_controller.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';

class FakeNotesRepository implements NotesRepository {
  final List<Note> notes;
  FakeNotesRepository([List<Note>? initial]) : notes = initial ?? [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Note>> getAllNotes() async => List.unmodifiable(notes);

  @override
  Future<void> saveNote(Note note) async {
    notes.removeWhere((n) => n.id == note.id || (n.originalAudioPath != null && n.originalAudioPath == note.originalAudioPath));
    notes.add(note);
  }

  @override
  Future<void> markAsRead(int id) async {
    for (final note in notes) {
      if (note.id == id) {
        note.isRead = true;
      }
    }
  }

  @override
  Future<void> updateNoteText(int id, String text) async {
    for (final note in notes) {
      if (note.id == id) {
        note.correctedText = text;
      }
    }
  }

  @override
  Future<void> updateNoteFolder(int id, String folder) async {
    for (final note in notes) {
      if (note.id == id) {
        note.folder = folder;
      }
    }
  }
}

class FakeQueueItemsNotifier extends QueueItemsNotifier {
  final List<AudioQueueItem> _initial;
  FakeQueueItemsNotifier([List<AudioQueueItem>? initial]) : _initial = initial ?? [];

  @override
  List<AudioQueueItem> build() => _initial;

  @override
  void setItems(List<AudioQueueItem> items) {
    state = List.unmodifiable(items);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 7 Verification: Immediate Feed Hydration, Audio Playback & Failed Triage', () {
    testWidgets('1. FR9.1: Enqueued audio immediately renders pastel yellow card in feed with audio playback button without restart', (tester) async {
      final queueNotifier = FakeQueueItemsNotifier([
        AudioQueueItem(
          id: '1001',
          audioFilePath: '/data/user/0/recording_1001.wav',
          recordedAt: DateTime(2026, 10, 29, 14, 0),
          status: AudioQueueStatus.pending,
        ),
      ]);

      final repo = FakeNotesRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repo),
            backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
              const BackgroundPermissionStatus(
                isAccessibilityEnabled: true,
                isBatteryOptimizationIgnored: true,
                isForegroundServiceRunning: true,
              ),
            )),
            pendingQueueCountProvider.overrideWith(() => PendingQueueCountNotifier()),
            failedQueueCountProvider.overrideWith(() => FailedQueueCountNotifier()),
            queueItemsProvider.overrideWith(() => queueNotifier),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify immediate appearance of enqueued note card in feed
      expect(find.text('⏳ Enqueued'), findsOneWidget);
      expect(find.text('Transcribing & organizing speech...'), findsOneWidget);

      // Verify audio play button is present for playback of original audio
      expect(find.byKey(const Key('play_audio_button')), findsOneWidget);
    });

    testWidgets('2. FR9.1: Processing completion replaces enqueued placeholder with processed note without restart', (tester) async {
      final queueNotifier = FakeQueueItemsNotifier([
        AudioQueueItem(
          id: '1002',
          audioFilePath: '/data/user/0/recording_1002.wav',
          recordedAt: DateTime(2026, 10, 29, 14, 5),
          status: AudioQueueStatus.pending,
        ),
      ]);

      final repo = FakeNotesRepository([]);

      late ProviderContainer container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
                const BackgroundPermissionStatus(
                  isAccessibilityEnabled: true,
                  isBatteryOptimizationIgnored: true,
                  isForegroundServiceRunning: true,
                ),
              )),
              pendingQueueCountProvider.overrideWith(() => PendingQueueCountNotifier()),
              failedQueueCountProvider.overrideWith(() => FailedQueueCountNotifier()),
              queueItemsProvider.overrideWith(() => queueNotifier),
            ],
          ),
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('⏳ Enqueued'), findsOneWidget);

      // Simulate worker saving completed note to repository and invalidating recentNotesProvider
      final completedNote = Note(
        originalAudioPath: '/data/user/0/recording_1002.wav',
        rawText: 'Schedule meeting tomorrow at 3pm',
        correctedText: 'Schedule meeting tomorrow at 3:00 PM.',
        folder: 'Work',
        createdAt: DateTime(2026, 10, 29, 14, 5),
        state: ThoughtState.processed,
      )..id = 1;

      await repo.saveNote(completedNote);
      queueNotifier.setItems([]);
      container.invalidate(recentNotesProvider);

      await tester.pumpAndSettle();

      // Verify enqueued state is gone and processed card is immediately displayed
      expect(find.text('⏳ Enqueued'), findsNothing);
      expect(find.text('Schedule meeting tomorrow at 3:00 PM.'), findsOneWidget);
      expect(find.widgetWithText(ThoughtCard, 'Work'), findsOneWidget);
      expect(find.byKey(const Key('play_audio_button')), findsOneWidget);
    });

    testWidgets('3. FR9.2: Tapping play audio button triggers audio playback controller', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.eudemonia/audio_playback'),
        (call) async => true,
      );

      final queueNotifier = FakeQueueItemsNotifier([
        AudioQueueItem(
          id: '1003',
          audioFilePath: '/data/user/0/recording_1003.wav',
          recordedAt: DateTime(2026, 10, 29, 14, 10),
          status: AudioQueueStatus.pending,
        ),
      ]);

      final repo = FakeNotesRepository([]);

      late ProviderContainer container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              notesRepositoryProvider.overrideWithValue(repo),
              backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
                const BackgroundPermissionStatus(
                  isAccessibilityEnabled: true,
                  isBatteryOptimizationIgnored: true,
                  isForegroundServiceRunning: true,
                ),
              )),
              pendingQueueCountProvider.overrideWith(() => PendingQueueCountNotifier()),
              failedQueueCountProvider.overrideWith(() => FailedQueueCountNotifier()),
              queueItemsProvider.overrideWith(() => queueNotifier),
            ],
          ),
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final playButton = find.byKey(const Key('play_audio_button'));
      expect(playButton, findsOneWidget);

      // Verify initially not playing
      expect(container.read(audioPlaybackControllerProvider).isPlaying, isFalse);

      // Tap play button
      await tester.tap(playButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify playback controller is playing the note's audio file path
      expect(container.read(audioPlaybackControllerProvider).isPlaying, isTrue);
      expect(container.read(audioPlaybackControllerProvider).currentlyPlayingPath, '/data/user/0/recording_1003.wav');

      // Tap again to pause
      await tester.tap(playButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(audioPlaybackControllerProvider).isPlaying, isFalse);
    });

    testWidgets('4. FR9.6: Failed items render as cards with no top banner and allow Failed chip filtering', (tester) async {
      final queueNotifier = FakeQueueItemsNotifier([
        AudioQueueItem(
          id: '1004',
          audioFilePath: '/data/user/0/failed_audio.wav',
          recordedAt: DateTime(2026, 10, 29, 14, 15),
          status: AudioQueueStatus.failed,
          errorMessage: 'Audio level too low or background noise too loud.',
        ),
      ]);

      final repo = FakeNotesRepository([
        Note(
          originalAudioPath: '/data/user/0/ok_audio.wav',
          rawText: 'Regular note',
          correctedText: 'Regular note.',
          folder: 'Ideas',
          createdAt: DateTime(2026, 10, 29, 14, 0),
          state: ThoughtState.processed,
        )..id = 2,
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repo),
            backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
              const BackgroundPermissionStatus(
                isAccessibilityEnabled: true,
                isBatteryOptimizationIgnored: true,
                isForegroundServiceRunning: true,
              ),
            )),
            pendingQueueCountProvider.overrideWith(() => PendingQueueCountNotifier()),
            failedQueueCountProvider.overrideWith(() => FailedQueueCountNotifier()),
            queueItemsProvider.overrideWith(() => queueNotifier),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify top banner is REMOVED
      expect(find.textContaining('thought(s) failed to process'), findsNothing);

      // Both cards are visible under All
      expect(find.text('Regular note.'), findsOneWidget);
      expect(find.text('Audio level too low or background noise too loud.'), findsOneWidget);
      expect(find.byKey(const Key('retry_button')), findsOneWidget);

      // Filter chips verify
      expect(find.byKey(const Key('filter_chip_all')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_unread')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_failed')), findsOneWidget);
      expect(find.text('Failed (1)'), findsOneWidget);

      // Tap Failed filter chip
      await tester.tap(find.byKey(const Key('filter_chip_failed')));
      await tester.pumpAndSettle();

      // Only failed card should be visible
      expect(find.text('Audio level too low or background noise too loud.'), findsOneWidget);
      expect(find.text('Regular note.'), findsNothing);

      // Tap Unread filter chip
      await tester.tap(find.byKey(const Key('filter_chip_unread')));
      await tester.pumpAndSettle();

      // Regular note (unread) is shown, failed note is not shown in unread
      expect(find.text('Regular note.'), findsOneWidget);
      expect(find.text('Audio level too low or background noise too loud.'), findsNothing);
    });
  });
}
