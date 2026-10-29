import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/home_screen.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/home/presentation/smooth_processing_indicator.dart';

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

void main() {
  group('TASK-031 Widget Tests: Cold Start Queue Hydration', () {
    testWidgets('1. AppBar displays 3 pending pill immediately on launch before worker loop starts', (tester) async {
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
            pendingQueueCountProvider.overrideWith(() => FakePendingQueueCountNotifier(3)),
            failedQueueCountProvider.overrideWith(() => FakeFailedQueueCountNotifier(0)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();

      // Assert AppBar pill displays '3 pending'
      expect(find.text('3 pending'), findsOneWidget);
    });

    testWidgets('2. In-body processing card renders with active indicator on cold start', (tester) async {
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
            pendingQueueCountProvider.overrideWith(() => FakePendingQueueCountNotifier(3)),
            failedQueueCountProvider.overrideWith(() => FakeFailedQueueCountNotifier(0)),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();

      // Assert in-body banner renders active pending thought indicator
      expect(find.text('Processing voice thought (3 pending)...'), findsOneWidget);
      expect(find.byType(SmoothProcessingIndicator), findsWidgets);
    });
  });
}
