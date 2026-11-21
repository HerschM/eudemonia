import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/batch_pipeline_service.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

class FakeQueueItemsNotifier extends QueueItemsNotifier {
  final List<AudioQueueItem> initial;
  FakeQueueItemsNotifier(this.initial);
  @override
  List<AudioQueueItem> build() => initial;
}

class FakeBatchPipelineService implements BatchPipelineService {
  bool isCapturing = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> startRecording() async {
    if (isCapturing) throw StateError('already capturing');
    isCapturing = true;
    return true;
  }

  @override
  Future<AudioQueueItem?> stopRecordingAndProcess() async {
    if (!isCapturing) throw StateError('no active capture');
    isCapturing = false;
    return AudioQueueItem(
      id: '1',
      audioFilePath: '/captures/1.wav',
      recordedAt: DateTime.now(),
      sequenceNumber: 7,
    );
  }
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
    BatchPipelineService? pipeline,
    bool permissionsGranted = true,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notesRepo ?? NotesRepository()),
          backgroundPermissionStatusProvider.overrideWith((ref) => Future.value(
                BackgroundPermissionStatus(
                  isAccessibilityEnabled: permissionsGranted,
                  isBatteryOptimizationIgnored: permissionsGranted,
                  isForegroundServiceRunning: true,
                ),
              )),
          queueItemsProvider.overrideWith(() => FakeQueueItemsNotifier(queueItems)),
          if (clusters != null)
            synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
          if (pipeline != null) batchPipelineProvider.overrideWithValue(pipeline),
        ],
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CaptureScreen layout (FR9, FR11.2) on a 360dp viewport', () {
    testWidgets('renders dual dropdown filters and the floating capsule, without the legacy folder carousel',
        (tester) async {
      await pumpCapture(tester);

      expect(find.byKey(const Key('capture_triage_filter_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('capture_status_filter_dropdown')), findsOneWidget);
      expect(find.text('All Triage'), findsOneWidget);
      expect(find.text('All Statuses'), findsOneWidget);
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
      expect(find.text('Press Vol Up + Down to Capture'), findsOneWidget);

      // Removed: horizontal folder carousel, legacy headings and chip filters.
      expect(find.text('Folders'), findsNothing);
      expect(find.text('Recent Thoughts'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('No thoughts yet.\nPress both volume buttons to capture.'), findsOneWidget);
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

    testWidgets('ambient permission banner appears only while background permissions are missing',
        (tester) async {
      await pumpCapture(tester, permissionsGranted: false);
      expect(find.textContaining('Background capture permissions needed'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      final pipeline = FakeBatchPipelineService();
      await pumpCapture(tester, pipeline: pipeline);

      await tester.tap(find.byKey(const Key('floating_capture_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(pipeline.isCapturing, isTrue);
      expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget);
      expect(find.text('00:00 • Tap to Stop'), findsOneWidget);
      expect(find.text('Press Vol Up + Down to Capture'), findsNothing);

      // The controller debounces triggers closer than 500ms apart (wall clock).
      await tester.runAsync(() => Future<void>.delayed(
          CaptureController.triggerCooldown + const Duration(milliseconds: 50)));

      await tester.tap(find.byKey(const Key('floating_capture_button_active')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(pipeline.isCapturing, isFalse);
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
      expect(find.text('Captured a new note [#07]'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
