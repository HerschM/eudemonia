import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/home_screen.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';

class MockNotesRepo implements NotesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Note>> getAllNotes() async => [];

  @override
  Future<List<Note>> getNotesByFolder(String folder) async => [];

  @override
  Future<void> saveNote(Note note) async {}
}

class FakePendingQueueCountNotifier extends PendingQueueCountNotifier {
  final int initial;
  FakePendingQueueCountNotifier(this.initial);
  @override
  int build() => initial;
}

class FakeFailedQueueCountNotifier extends FailedQueueCountNotifier {
  final int initial;
  FakeFailedQueueCountNotifier(this.initial);
  @override
  int build() => initial;
}

class FakeQueueItemsNotifier extends QueueItemsNotifier {
  final List<AudioQueueItem> initial;
  FakeQueueItemsNotifier(this.initial);
  @override
  List<AudioQueueItem> build() => initial;
}

void main() {
  testWidgets('Pending queue indicator displays in AppBar and in body banner when items are queued', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(MockNotesRepo()),
          backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
            const BackgroundPermissionStatus(
              isAccessibilityEnabled: true,
              isBatteryOptimizationIgnored: true,
              isForegroundServiceRunning: true,
            ),
          )),
          pendingQueueCountProvider.overrideWith(() => FakePendingQueueCountNotifier(2)),
          failedQueueCountProvider.overrideWith(() => FakeFailedQueueCountNotifier(0)),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify AppBar badge and in-body banner are visible
    expect(find.text('2 pending'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Processing voice thought'), findsOneWidget);
  });

  testWidgets('Pending queue indicator and body banner are hidden when pending queue count is 0', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(MockNotesRepo()),
          backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
            const BackgroundPermissionStatus(
              isAccessibilityEnabled: true,
              isBatteryOptimizationIgnored: true,
              isForegroundServiceRunning: true,
            ),
          )),
          pendingQueueCountProvider.overrideWith(() => FakePendingQueueCountNotifier(0)),
          failedQueueCountProvider.overrideWith(() => FakeFailedQueueCountNotifier(0)),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('0 pending'), findsNothing);
    expect(find.textContaining('Processing voice thought'), findsNothing);
  });

  testWidgets('Failed items are rendered as cards in feed with Failed chip and no top banner', (tester) async {
    final failedItem = AudioQueueItem(
      id: '999',
      audioFilePath: '/mock/path/failed.wav',
      recordedAt: DateTime.now(),
      status: AudioQueueStatus.failed,
      errorMessage: 'Network timeout during transcription.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(MockNotesRepo()),
          backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
            const BackgroundPermissionStatus(
              isAccessibilityEnabled: true,
              isBatteryOptimizationIgnored: true,
              isForegroundServiceRunning: true,
            ),
          )),
          pendingQueueCountProvider.overrideWith(() => FakePendingQueueCountNotifier(0)),
          failedQueueCountProvider.overrideWith(() => FakeFailedQueueCountNotifier(1)),
          queueItemsProvider.overrideWith(() => FakeQueueItemsNotifier([failedItem])),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify top banner is REMOVED
    expect(find.textContaining('thought(s) failed to process'), findsNothing);

    // Verify Failed filter chip is present
    expect(find.byKey(const Key('filter_chip_failed')), findsOneWidget);
    expect(find.text('Failed (1)'), findsOneWidget);

    // Verify failed thought card displays in-entry failure message and retry button
    expect(find.text('Network timeout during transcription.'), findsOneWidget);
    expect(find.byKey(const Key('retry_button')), findsOneWidget);
  });
}
