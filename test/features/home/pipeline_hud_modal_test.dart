import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/resident_model.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/system_telemetry_service.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

const _mb = 1024 * 1024;

class _QuietLogger extends AppLogger {
  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {dynamic error, StackTrace? stackTrace}) async {}
}

/// Answers every reading with [appMemoryMb] at that moment and counts the readings.
class _FakeTelemetry extends SystemTelemetryService {
  int reads = 0;
  int appMemoryMb = 40;

  @override
  Future<SystemTelemetry?> read() async {
    reads++;
    return SystemTelemetry(appMemoryBytes: appMemoryMb * _mb);
  }
}

SynthesisCluster _session(String id, {bool flagged = false}) => SynthesisCluster(
      clusterId: id,
      sequenceNumber: '#S-01',
      folder: 'Work',
      synthesizedContent: 'Note $id',
      sessionStart: DateTime(2026, 11, 27, 9),
      sessionEnd: DateTime(2026, 11, 27, 9),
      sessionDuration: Duration.zero,
      originNotes: [
        SynthesisOriginNote(id: 1, formattedSequence: '#01', cleanedText: 'Thought', timestamp: DateTime(2026, 11, 27, 9)),
      ],
      isReprocessing: flagged,
    );

void main() {
  Future<void> pump(WidgetTester tester, int ready) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PipelineHudModal(
          captureTranscribingCount: 0,
          synthesisReadyCount: ready,
          onSynthesizeNow: () {},
          memoryLine: 'Memory 40 MB',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('Synthesis stage counts waiting thoughts in plain words, singular and plural', (tester) async {
    await pump(tester, 1);
    expect(find.text('1 thought ready for Synthesis'), findsOneWidget);
    expect(find.textContaining('cluster'), findsNothing);

    await pump(tester, 3);
    expect(find.text('3 thoughts ready for Synthesis'), findsOneWidget);
  });

  group('the sheet follows the live pipeline', () {
    late ProviderContainer container;
    late _FakeTelemetry telemetry;

    Future<void> openSheet(WidgetTester tester, {List<SynthesisCluster> sessions = const []}) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      telemetry = _FakeTelemetry();
      container = ProviderContainer(overrides: [
        notesRepositoryProvider.overrideWithValue(NotesRepository()),
        synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(sessions)),
        synthesisSessionStoreProvider.overrideWithValue(SynthesisSessionStore()),
        systemTelemetryServiceProvider.overrideWithValue(telemetry),
        appLoggerProvider.overrideWithValue(_QuietLogger()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => PipelineHudModal.show(context, onSynthesizeNow: () {}),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    String memoryLine(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('hud_memory_telemetry'))).data!;

    testWidgets('a rewrite with no new thoughts shows as a rewrite in progress, as the chip does', (tester) async {
      await openSheet(tester, sessions: [_session('a', flagged: true), _session('b')]);
      expect(find.text('1 note waiting to be rewritten'), findsOneWidget);
      expect(find.text('All sessions consolidated'), findsNothing);

      container.read(synthesisRunningProvider.notifier).setRunning(true);
      await tester.pump();
      expect(find.text('Rewriting 1 note'), findsOneWidget);
      expect(find.text('All sessions consolidated'), findsNothing);
      expect(container.read(pipelineStatusProvider).isActive, isTrue);

      container.read(synthesisRunningProvider.notifier).setRunning(false);
      container.read(synthesisRepositoryProvider.notifier).clearReprocessing('a');
      await tester.pump();
      expect(find.text('All sessions consolidated'), findsOneWidget);
    });

    testWidgets('a run with nothing counted yet still shows that it is working', (tester) async {
      await openSheet(tester);
      container.read(synthesisRunningProvider.notifier).setRunning(true);
      await tester.pump();
      expect(find.text('Writing your notes'), findsOneWidget);
      expect(find.text('All sessions consolidated'), findsNothing);
    });

    testWidgets('the counts change while the sheet is open', (tester) async {
      await openSheet(tester);
      expect(find.text('All raw voice recordings transcribed'), findsOneWidget);

      container.read(pendingQueueCountProvider.notifier).setCount(2);
      await tester.pump();
      expect(find.text('2 audio recording transcribing'), findsOneWidget);

      await container.read(notesRepositoryProvider).saveNote(Note(correctedText: 'Waiting'));
      container.read(notesRevisionProvider.notifier).bump();
      await tester.pumpAndSettle();
      expect(find.text('1 thought ready for Synthesis'), findsOneWidget);
    });

    testWidgets('the memory line names the model really in memory and follows it', (tester) async {
      await openSheet(tester);
      expect(memoryLine(tester), 'AI models unloaded • App memory 40 MB');

      container.read(modelLifecycleStateProvider.notifier).setLifecycleState(ModelLifecycleState.ready);
      await tester.pump();
      expect(memoryLine(tester), 'Speech model loaded • App memory 40 MB');

      container.read(modelLifecycleStateProvider.notifier).setLifecycleState(ModelLifecycleState.unloaded);
      container.read(languageModelStateProvider.notifier).setState(ModelLifecycleState.loading);
      await tester.pump();
      expect(memoryLine(tester), 'Writing model loading • App memory 40 MB');

      container.read(languageModelStateProvider.notifier).setState(ModelLifecycleState.ready);
      // A recording asked for speech while a note is being written: the writing model is still in memory.
      container.read(modelLifecycleStateProvider.notifier).setLifecycleState(ModelLifecycleState.loading);
      await tester.pump();
      expect(memoryLine(tester), 'Writing model loaded • App memory 40 MB');
    });

    testWidgets('memory is read again on a short interval while open, and never once closed', (tester) async {
      await openSheet(tester);
      expect(telemetry.reads, 1);
      expect(memoryLine(tester), 'AI models unloaded • App memory 40 MB');

      telemetry.appMemoryMb = 1800;
      await tester.pump(pipelineHudRefreshInterval);
      await tester.pump();
      expect(telemetry.reads, 2);
      expect(memoryLine(tester), 'AI models unloaded • App memory 1.76 GB');

      await tester.tap(find.byKey(const Key('close_pipeline_hud_button')));
      await tester.pumpAndSettle();
      final readsWhenClosed = telemetry.reads;
      await tester.pump(pipelineHudRefreshInterval * 10);
      expect(telemetry.reads, readsWhenClosed);
    });
  });

  group('pipelineStatusProvider', () {
    test('the chip total and every stage come from the same counts', () async {
      final container = ProviderContainer(overrides: [
        notesRepositoryProvider.overrideWithValue(NotesRepository()),
        synthesisRepositoryProvider.overrideWith(() => SynthesisRepository([_session('a', flagged: true)])),
        synthesisSessionStoreProvider.overrideWithValue(SynthesisSessionStore()),
        appLoggerProvider.overrideWithValue(_QuietLogger()),
      ]);
      addTearDown(container.dispose);
      container.listen(pipelineStatusProvider, (_, _) {});
      container.read(pendingQueueCountProvider.notifier).setCount(2);
      await container.read(notesRepositoryProvider).saveNote(Note(correctedText: 'Waiting'));
      container.read(notesRevisionProvider.notifier).bump();
      await container.read(rawNotesReadyToClusterCountProvider.future);

      final status = container.read(pipelineStatusProvider);
      expect(status.transcribing, 2);
      expect(status.readyThoughts, 1);
      expect(status.rewriting, 1);
      expect(status.pending, 4);
      expect(status.isActive, isTrue);
      expect(status.synthesizing, isFalse);
      expect(status.residentModel, ResidentModel.none);
    });
  });
}
