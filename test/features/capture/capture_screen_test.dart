import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:permission_handler/permission_handler.dart';

import '../settings/fake_permission_gateway.dart';
import 'capture_test_doubles.dart';

class FakeQueueItemsNotifier extends QueueItemsNotifier {
  final List<AudioQueueItem> initial;
  FakeQueueItemsNotifier(this.initial);
  @override
  List<AudioQueueItem> build() => initial;
}

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpCapture(
    WidgetTester tester, {
    NotesRepository? notesRepo,
    List<AudioQueueItem> queueItems = const [],
    List<SynthesisCluster>? clusters,
    FakeNativeCaptureChannel? channel,
    FakeCaptureInboxIngestor? ingestor,
    FakePermissionGateway? permissions,
    // The listening waveform animates forever, so a recording in progress cannot settle.
    bool settle = true,
    // The record capsule belongs to the navigation shell: tests of it pump the shell, on Capture.
    bool inShell = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo ?? NotesRepository()),
          runtimePermissionGatewayProvider.overrideWithValue(permissions ?? FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(channel ?? FakeNativeCaptureChannel()),
          captureInboxIngestorProvider.overrideWithValue(ingestor ?? FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          queueItemsProvider.overrideWith(() => FakeQueueItemsNotifier(queueItems)),
          if (clusters != null)
            synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
        ],
        child: MaterialApp(home: inShell ? const MainNavigationShell(initialIndex: 0) : const CaptureScreen()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('CaptureScreen layout (FR9, FR11.2) on a 360dp viewport', () {
    testWidgets('renders dual dropdown filters and the floating capsule, without the legacy folder carousel',
        (tester) async {
      await pumpCapture(tester, inShell: true);

      expect(find.byKey(const Key('capture_triage_filter_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('capture_status_filter_dropdown')), findsOneWidget);
      expect(find.text('All Triage'), findsOneWidget);
      expect(find.text('All Statuses'), findsOneWidget);
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
      expect(find.text('Tap to capture'), findsOneWidget);

      // Removed: horizontal folder carousel, legacy headings and chip filters.
      expect(find.text('Folders'), findsNothing);
      expect(find.text('Recent Thoughts'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text(
              'No thoughts yet.\nTap the mic below, the Record button in your notifications, or the home-screen widget.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('groups thoughts under a day header and shows no folder on any card', (tester) async {
      final repo = NotesRepository();
      await repo.saveNote(Note(correctedText: 'Fresh thought.'));

      await pumpCapture(tester, notesRepo: repo);

      expect(find.textContaining('TODAY — '), findsOneWidget);
      expect(find.text('Fresh thought.'), findsOneWidget);
      expect(find.text('Work'), findsNothing);
      expect(find.byKey(const Key('category_dropdown_button')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no banner while the microphone and notifications are granted, whatever the battery state',
        (tester) async {
      await pumpCapture(tester);

      expect(find.byKey(const Key('capture_readiness_banner')), findsNothing);
      expect(find.textContaining('Battery'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missing microphone shows the Allow banner and Allow requests it', (tester) async {
      final permissions = FakePermissionGateway(microphone: PermissionStatus.denied);
      await pumpCapture(tester, permissions: permissions);

      expect(find.text('Microphone access is needed to capture thoughts.'), findsOneWidget);
      expect(find.text('Turn on'), findsNothing);

      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      expect(permissions.requested, [Permission.microphone]);
      expect(find.byKey(const Key('capture_readiness_banner')), findsNothing);
    });

    testWidgets('a permanently denied microphone sends Allow to the system settings', (tester) async {
      final permissions = FakePermissionGateway(microphone: PermissionStatus.permanentlyDenied);
      await pumpCapture(tester, permissions: permissions);

      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();

      expect(permissions.settingsOpened, 1);
      expect(permissions.requested, isEmpty);
    });

    testWidgets('with the microphone granted, off notifications show the Turn on banner', (tester) async {
      final permissions = FakePermissionGateway(notification: PermissionStatus.denied);
      await pumpCapture(tester, permissions: permissions);

      expect(
        find.text('Notifications are off, so the Record button on your lock screen is hidden.'),
        findsOneWidget,
      );
      expect(find.text('Allow'), findsNothing);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();

      expect(permissions.requested, [Permission.notification]);
      expect(find.byKey(const Key('capture_readiness_banner')), findsNothing);
    });

    testWidgets('a missing microphone takes precedence over off notifications', (tester) async {
      await pumpCapture(
        tester,
        permissions: FakePermissionGateway(
          microphone: PermissionStatus.denied,
          notification: PermissionStatus.denied,
        ),
      );

      expect(find.text('Microphone access is needed to capture thoughts.'), findsOneWidget);
      expect(find.textContaining('Notifications are off'), findsNothing);
    });
  });

  group('CaptureScreen status and triage filtering (FR9.2)', () {
    testWidgets('failed queue item renders in-card with Retry and is isolated by the Failed status filter',
        (tester) async {
      final repo = NotesRepository();
      await repo.saveNote(Note(correctedText: 'Healthy thought.'));
      final failedItem = AudioQueueItem(
        id: '999',
        audioFilePath: '/mock/path/failed.wav',
        recordedAt: DateTime.now(),
        status: AudioQueueStatus.failed,
        errorMessage: 'Network timeout during transcription.',
      );

      await pumpCapture(tester, notesRepo: repo, queueItems: [failedItem]);

      expect(find.textContaining('thought(s) failed to process'), findsNothing);
      expect(find.text('Network timeout during transcription.'), findsOneWidget);
      expect(find.byKey(const Key('retry_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Failed').last);
      await tester.pumpAndSettle();

      expect(find.text('Network timeout during transcription.'), findsOneWidget);
      expect(find.text('Healthy thought.'), findsNothing);
    });

    testWidgets('a silent recording is a calm card: no Retry, not in the Failed filter; a real failure keeps both',
        (tester) async {
      final repo = NotesRepository();
      final silentItem = AudioQueueItem(
        id: '1',
        audioFilePath: '/mock/path/silent.wav',
        recordedAt: DateTime.now(),
        status: AudioQueueStatus.failed,
        errorMessage: silentRecordingMessage,
      );
      final failedItem = AudioQueueItem(
        id: '2',
        audioFilePath: '/mock/path/failed.wav',
        recordedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        status: AudioQueueStatus.failed,
        errorMessage: 'Network timeout during transcription.',
      );

      await pumpCapture(tester, notesRepo: repo, queueItems: [silentItem, failedItem]);

      expect(find.text('Nothing was heard in this recording.'), findsOneWidget);
      expect(find.text('Network timeout during transcription.'), findsOneWidget);
      expect(find.byKey(const Key('retry_button')), findsOneWidget, reason: 'only the real failure');
      expect(find.text('⚠️ Failed'), findsOneWidget, reason: 'only the real failure');

      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Failed').last);
      await tester.pumpAndSettle();

      expect(find.text('Network timeout during transcription.'), findsOneWidget);
      expect(find.text('Nothing was heard in this recording.'), findsNothing);
    });

    testWidgets('Synthesized filter shows only clubbed thoughts, labelled with their session', (tester) async {
      final repo = NotesRepository();
      final clubbed = Note(correctedText: 'Clubbed thought.', state: ThoughtState.synthesized);
      await repo.saveNote(clubbed);
      await repo.saveNote(Note(correctedText: 'Loose thought.'));
      final cluster = SynthesisCluster(
        clusterId: 'c1',
        sequenceNumber: '#S-04',
        folder: 'Ideas',
        synthesizedContent: 'Narrative',
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
        sessionDuration: const Duration(minutes: 15),
        originNotes: [SynthesisOriginNote.fromNote(clubbed)],
      );

      await pumpCapture(tester, notesRepo: repo, clusters: [cluster]);

      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthesized').last);
      await tester.pumpAndSettle();

      expect(find.text('Clubbed thought.'), findsOneWidget);
      expect(find.text('Loose thought.'), findsNothing);
      expect(find.textContaining('Synthesized in #S-04'), findsOneWidget);
    });

    testWidgets('a thought consumed by a session of another day names that day', (tester) async {
      final repo = NotesRepository();
      final now = DateTime.now();
      final late = DateTime(now.year, now.month, now.day, 0, 5);
      final dayBefore = late.subtract(const Duration(minutes: 20));
      final clubbed = Note(correctedText: 'Just after midnight.', createdAt: late, state: ThoughtState.synthesized);
      await repo.saveNote(clubbed);
      final cluster = SynthesisCluster(
        clusterId: 'c1',
        sequenceNumber: '#S-03',
        folder: 'Work',
        synthesizedContent: 'Narrative',
        sessionStart: dayBefore,
        sessionEnd: late,
        sessionDuration: const Duration(minutes: 20),
        originNotes: [SynthesisOriginNote.fromNote(clubbed)],
      );

      await pumpCapture(tester, notesRepo: repo, clusters: [cluster]);

      final dd = dayBefore.day.toString().padLeft(2, '0');
      final mm = dayBefore.month.toString().padLeft(2, '0');
      expect(find.textContaining('Synthesized in #S-03 · $dd/$mm'), findsOneWidget);
    });

    testWidgets('filters that match nothing explain themselves', (tester) async {
      final repo = NotesRepository();
      await repo.saveNote(Note(correctedText: 'Unread thought.'));

      await pumpCapture(tester, notesRepo: repo);
      await tester.tap(find.byKey(const Key('capture_triage_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read').last);
      await tester.pumpAndSettle();

      expect(find.text('No thoughts matching active filters'), findsOneWidget);
    });
  });

  group('Floating capture trigger (FR9.3)', () {
    testWidgets('tap starts listening with an elapsed timer; tapping again captures with clean feedback',
        (tester) async {
      final channel = FakeNativeCaptureChannel()
        ..saveOnStop = const PendingCapture(path: '/inbox/1.wav', startedAtMs: 1700000000000);
      await pumpCapture(tester, channel: channel, inShell: true);

      await tester.tap(find.byKey(const Key('floating_capture_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(channel.state.isRecording, isTrue);
      expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget);
      expect(find.text('00:00 • Tap to Stop'), findsOneWidget);
      expect(find.text('Tap to capture'), findsNothing);

      await tester.tap(find.byKey(const Key('floating_capture_button_active')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(channel.state.isRecording, isFalse);
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
      expect(find.text('Captured a new note [#01]'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a recording started from the notification shows its real elapsed time when the app is open',
        (tester) async {
      final channel = FakeNativeCaptureChannel()
        ..state = NativeCaptureState(
          isRecording: true,
          startedAtMs: DateTime.now().subtract(const Duration(seconds: 65, milliseconds: 200)).millisecondsSinceEpoch,
        );
      await pumpCapture(tester, channel: channel, settle: false, inShell: true);

      expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget);
      expect(find.text('01:05 • Tap to Stop'), findsOneWidget);
    });
  });
}
