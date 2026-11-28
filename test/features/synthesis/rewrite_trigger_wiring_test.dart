import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/capture/capture_controller.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/application/session_actions.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_session_store.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts runs and answers busy (so the trigger waits for a retry); never really runs. Its end is
/// reported through the app's run-end provider, as the real runner's is.
class _CountingRunner implements SynthesisRunner {
  final void Function(SynthesisRunResult result) ended;
  final List<SynthesisRunResult> results = [];
  int runs = 0;

  _CountingRunner(this.ended);

  @override
  bool get isRunning => false;

  @override
  Future<SynthesisRunResult> run({required bool manual}) async {
    runs++;
    final result = results.isEmpty ? SynthesisRunResult.busy : results.removeAt(0);
    ended(result);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Capture without the native recorder: idle until a test says otherwise.
class _Capture extends CaptureController {
  @override
  bool build() => false;

  void setRecording(bool value) => state = value;
}

class _QuietLogger extends AppLogger {
  @override
  Future<void> info(String message) async {}

  @override
  Future<void> warning(String message) async {}

  @override
  Future<void> error(String message, {dynamic error, StackTrace? stackTrace}) async {}
}

class _MemoryFolderStore implements FolderStore {
  @override
  Future<List<FolderDefinition>?> load() async => null;

  @override
  Future<void> save(List<FolderDefinition> folders) async {}
}

SynthesisCluster _session(String id, int thoughtId, {bool flagged = false}) => SynthesisCluster(
      clusterId: id,
      sequenceNumber: '#S-0$thoughtId',
      folder: 'Work',
      synthesizedContent: 'Note $id',
      sessionStart: DateTime(2026, 11, 27, 9, thoughtId),
      sessionEnd: DateTime(2026, 11, 27, 9, thoughtId),
      sessionDuration: Duration.zero,
      originNotes: [
        SynthesisOriginNote(
          id: thoughtId,
          formattedSequence: '#0$thoughtId',
          cleanedText: 'Thought $thoughtId',
          timestamp: DateTime(2026, 11, 27, 9, thoughtId),
        ),
      ],
      isReprocessing: flagged,
    );

void main() {
  late SynthesisSessionStore store;
  late ProviderContainer container;
  late _CountingRunner runner;

  setUp(() {
    store = SynthesisSessionStore();
    container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(NotesRepository()),
      synthesisSessionStoreProvider.overrideWithValue(store),
      folderStoreProvider.overrideWithValue(_MemoryFolderStore()),
      appLoggerProvider.overrideWithValue(_QuietLogger()),
      captureControllerProvider.overrideWith(_Capture.new),
      activeSynthesisProfileProvider.overrideWithValue(SynthesisModelProfile.qwen3_4b),
      synthesisRunnerProvider.overrideWith((ref) => runner = _CountingRunner(
            (result) => ref.read(synthesisRunEndProvider.notifier).ended(result),
          )),
    ]);
  });

  tearDown(() => container.dispose());

  /// What `main` does: the trigger is only read, never watched, and started.
  Future<SynthesisRepository> launch() async {
    await container.read(synthesisTriggerControllerProvider).start();
    final repo = container.read(synthesisRepositoryProvider.notifier);
    await repo.hydrated;
    await pumpEventQueue();
    return repo;
  }

  test('a session left flagged before a restart starts a run at app start', () async {
    await store.put(_session('a', 1, flagged: true));

    await launch();

    expect(runner.runs, 1);
  });

  test('nothing runs at app start without flagged sessions', () async {
    await store.put(_session('a', 1));

    await launch();

    expect(runner.runs, 0);
  });

  test('a merge starts a run that rewrites the merged note', () async {
    await store.put(_session('a', 1));
    await store.put(_session('b', 2));
    final repo = await launch();

    repo.mergeClusters('b', 'a');
    await pumpEventQueue();

    expect(container.read(synthesisRepositoryProvider).single.isReprocessing, isTrue);
    expect(runner.runs, 1);
  });

  test('a thought moved to another note starts a run', () async {
    await store.put(_session('a', 1));
    await store.put(SynthesisCluster(
      clusterId: 'b',
      sequenceNumber: '#S-02',
      folder: 'Work',
      synthesizedContent: 'Note b',
      sessionStart: DateTime(2026, 11, 27, 10),
      sessionEnd: DateTime(2026, 11, 27, 10, 5),
      sessionDuration: const Duration(minutes: 5),
      originNotes: [
        SynthesisOriginNote(id: 2, formattedSequence: '#02', cleanedText: 'Two', timestamp: DateTime(2026, 11, 27, 10)),
        SynthesisOriginNote(id: 3, formattedSequence: '#03', cleanedText: 'Three', timestamp: DateTime(2026, 11, 27, 10, 5)),
      ],
    ));
    final repo = await launch();

    repo.ejectRawNoteToTarget('b', 'a', 3);
    await pumpEventQueue();

    expect(runner.runs, 1);
  });

  test('a thought moved out into its own note starts one run, also with the action starting its own', () async {
    await store.put(SynthesisCluster(
      clusterId: 'b',
      sequenceNumber: '#S-02',
      folder: 'Work',
      synthesizedContent: 'Note b',
      sessionStart: DateTime(2026, 11, 27, 10),
      sessionEnd: DateTime(2026, 11, 27, 10, 5),
      sessionDuration: const Duration(minutes: 5),
      originNotes: [
        SynthesisOriginNote(id: 2, formattedSequence: '#02', cleanedText: 'Two', timestamp: DateTime(2026, 11, 27, 10)),
        SynthesisOriginNote(id: 3, formattedSequence: '#03', cleanedText: 'Three', timestamp: DateTime(2026, 11, 27, 10, 5)),
      ],
    ));
    await launch();

    await container.read(sessionActionsProvider).moveThoughtOut('b', 3);
    await pumpEventQueue();

    final sessions = container.read(synthesisRepositoryProvider);
    expect(sessions, hasLength(2));
    expect(sessions.every((s) => s.isReprocessing), isTrue);
    expect(runner.runs, greaterThanOrEqualTo(1));
  });

  test('a flag set while a thought is transcribing starts its run once the queue is empty', () async {
    await store.put(_session('a', 1));
    await store.put(_session('b', 2));
    final repo = await launch();
    container.read(pendingQueueCountProvider.notifier).setCount(1);

    repo.mergeClusters('b', 'a');
    await pumpEventQueue();
    expect(runner.runs, 0);

    container.read(pendingQueueCountProvider.notifier).setCount(0);
    await pumpEventQueue();
    expect(runner.runs, 1);
  });

  test('a flag set while recording starts its run once the recording stops', () async {
    await store.put(_session('a', 1));
    await store.put(_session('b', 2));
    final repo = await launch();
    final capture = container.read(captureControllerProvider.notifier) as _Capture;
    capture.setRecording(true);

    repo.mergeClusters('b', 'a');
    await pumpEventQueue();
    expect(runner.runs, 0);

    capture.setRecording(false);
    await pumpEventQueue();
    expect(runner.runs, 1);
  });

  test('the end of a run started elsewhere starts the rewrite it left', () async {
    await store.put(_session('a', 1, flagged: true));
    // The run at launch is busy; the end of a run started elsewhere checks again at once.
    await launch();
    expect(runner.runs, 1);

    container.read(synthesisRunEndProvider.notifier).ended(SynthesisRunResult.completed);
    await pumpEventQueue();

    expect(runner.runs, 2);
  });
}
