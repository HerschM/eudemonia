import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/home_screen.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';

class FakeNotesRepository implements NotesRepository {
  final List<Note> notes;
  FakeNotesRepository(this.notes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Note>> getAllNotes() async => List.from(notes);

  @override
  Future<void> markAsRead(int id) async {
    final note = notes.where((n) => n.id == id).firstOrNull;
    if (note != null) {
      note.isRead = true;
    }
  }

  @override
  Future<void> updateNoteText(int id, String newText) async {
    final note = notes.where((n) => n.id == id).firstOrNull;
    if (note != null) {
      note.correctedText = newText;
    }
  }

  @override
  Future<void> updateNoteFolder(int id, String newFolder) async {
    final note = notes.where((n) => n.id == id).firstOrNull;
    if (note != null) {
      note.folder = newFolder;
    }
  }
}

class FakeQueueCountNotifier extends PendingQueueCountNotifier {
  @override
  int build() => 0;
}

class FakeFailedCountNotifier extends FailedQueueCountNotifier {
  @override
  int build() => 0;
}

void main() {
  group('TASK-035 Widget Tests: Unread / Viewed Thought Status Tracking & Triage Filter', () {
    testWidgets('1. Unread cards display electric blue dot beside timestamp', (tester) async {
      final unreadNote = Note(
        correctedText: 'Unread thought text',
        folder: 'Work',
        state: ThoughtState.processed,
        isRead: false,
      )..id = 1;

      final readNote = Note(
        correctedText: 'Read thought text',
        folder: 'Ideas',
        state: ThoughtState.processed,
        isRead: true,
      )..id = 2;

      final fakeRepo = FakeNotesRepository([unreadNote, readNote]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(fakeRepo),
            backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
              const BackgroundPermissionStatus(
                isAccessibilityEnabled: true,
                isBatteryOptimizationIgnored: true,
                isForegroundServiceRunning: true,
              ),
            )),
            pendingQueueCountProvider.overrideWith(() => FakeQueueCountNotifier()),
            failedQueueCountProvider.overrideWith(() => FakeFailedCountNotifier()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify unread dot is displayed exactly for unread note
      expect(find.byKey(const Key('unread_dot')), findsOneWidget);
      expect(find.text('Unread thought text'), findsOneWidget);
      expect(find.text('Read thought text'), findsOneWidget);
    });

    testWidgets('2. Tapping unread card clears indicator dot', (tester) async {
      final unreadNote = Note(
        correctedText: 'Tappable unread thought',
        folder: 'Work',
        state: ThoughtState.processed,
        isRead: false,
      )..id = 1;

      final fakeRepo = FakeNotesRepository([unreadNote]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(fakeRepo),
            backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
              const BackgroundPermissionStatus(
                isAccessibilityEnabled: true,
                isBatteryOptimizationIgnored: true,
                isForegroundServiceRunning: true,
              ),
            )),
            pendingQueueCountProvider.overrideWith(() => FakeQueueCountNotifier()),
            failedQueueCountProvider.overrideWith(() => FakeFailedCountNotifier()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect dot present
      expect(find.byKey(const Key('unread_dot')), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Tappable unread thought'));
      await tester.pumpAndSettle();

      // Expect dot gone because note was marked read and feed invalidated
      expect(find.byKey(const Key('unread_dot')), findsNothing);
    });

    testWidgets('3. Selecting Unread filter chip shows only unread notes', (tester) async {
      final unreadNote = Note(
        correctedText: 'Only unread note',
        folder: 'Work',
        state: ThoughtState.processed,
        isRead: false,
      )..id = 1;

      final readNote = Note(
        correctedText: 'Read note that should be filtered',
        folder: 'Ideas',
        state: ThoughtState.processed,
        isRead: true,
      )..id = 2;

      final fakeRepo = FakeNotesRepository([unreadNote, readNote]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(fakeRepo),
            backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
              const BackgroundPermissionStatus(
                isAccessibilityEnabled: true,
                isBatteryOptimizationIgnored: true,
                isForegroundServiceRunning: true,
              ),
            )),
            pendingQueueCountProvider.overrideWith(() => FakeQueueCountNotifier()),
            failedQueueCountProvider.overrideWith(() => FakeFailedCountNotifier()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both notes initially visible under 'All'
      expect(find.text('Only unread note'), findsOneWidget);
      expect(find.text('Read note that should be filtered'), findsOneWidget);

      // Tap 'Unread' filter chip
      final unreadChip = find.byKey(const Key('filter_chip_unread'));
      expect(unreadChip, findsOneWidget);
      await tester.tap(unreadChip);
      await tester.pumpAndSettle();

      // Only unread note should be visible
      expect(find.text('Only unread note'), findsOneWidget);
      expect(find.text('Read note that should be filtered'), findsNothing);
    });
  });
}
