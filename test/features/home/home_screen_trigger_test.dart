import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/home_screen.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';

class MockNotesRepo implements NotesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<List<Note>> getRecentNotes({int limit = 50}) async => [];

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

  testWidgets('Failed items banner displays with Retry action when a note fails', (tester) async {
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
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('failed to process'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
