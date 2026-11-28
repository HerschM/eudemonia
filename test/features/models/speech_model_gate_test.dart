import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/cpu_wake_lock.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/application/model_settings.dart';
import 'package:eudemonia/features/models/data/model_files_channel.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_settings.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_trigger_controller.dart';
import 'package:eudemonia/features/synthesis/presentation/manual_synthesis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_test_doubles.dart';

/// Transcribes anything once initialised; fails loudly if used before.
class _Stt extends STTService {
  bool _ready = false;
  int transcriptions = 0;

  @override
  bool get isInitialized => _ready;

  @override
  Future<void> initialize(String modelDir) async => _ready = true;

  @override
  Future<String> transcribe(String audioFilePath) async {
    if (!_ready) throw StateError('STT used before initialize');
    transcriptions++;
    return 'a thought';
  }

  @override
  void dispose() => _ready = false;
}

class _NoopWakeLock implements CpuWakeLock {
  @override
  Future<void> hold(Duration timeout) async {}

  @override
  Future<void> release() async {}
}

class _NoModelRunner implements SynthesisRunner {
  int runs = 0;

  @override
  Future<SynthesisRunResult> run({required bool manual}) async {
    runs++;
    return SynthesisRunResult.noModel;
  }

  @override
  bool get isRunning => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const speech = ModelCatalogue.parakeetV2;

  group('audio queue and the speech model (FR16.2)', () {
    late FakeModelFilesChannel files;
    late _Stt stt;
    late NotesRepository notes;
    late ProviderContainer container;
    late ModelLifecycleManager lifecycle;

    setUp(() {
      files = FakeModelFilesChannel();
      stt = _Stt();
      notes = NotesRepository();
      lifecycle = ModelLifecycleManager(stt, modelsDirResolver: () async => '/models');
      container = ProviderContainer(overrides: [
        modelFilesChannelProvider.overrideWithValue(files),
        modelSettingsStoreProvider.overrideWithValue(InMemoryModelSettingsStore()),
        notesRepositoryProvider.overrideWithValue(notes),
        sttServiceProvider.overrideWithValue(stt),
        modelLifecycleManagerProvider.overrideWithValue(lifecycle),
        transcriptionWakeLockProvider.overrideWithValue(_NoopWakeLock()),
        synthesisTriggerControllerProvider.overrideWithValue(SynthesisTriggerController(
          runner: _NoModelRunner(),
          eligibleCount: () async => 0,
          settings: () => const SynthesisSettings(),
        )),
      ]);
    });

    tearDown(() {
      lifecycle.dispose();
      container.dispose();
    });

    // Plain tests: the queue does real file I/O, which a widget test's fake clock would never finish.
    Future<void> settle() => pumpEventQueue(times: 200);

    /// Waits in real time: the queue's own disk access finishes on the real event loop.
    Future<void> until(bool Function() condition) async {
      for (var i = 0; i < 300 && !condition(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(condition(), isTrue);
    }

    test('a thought recorded without the model waits, then is transcribed when the model arrives', () async {
      final queue = container.read(audioQueueServiceProvider);
      container.read(modelLibraryControllerProvider);
      await settle();

      await queue.enqueue('/audio/a.m4a');
      await settle();

      expect(queue.items.single.status, AudioQueueStatus.pending);
      expect(queue.items.single.errorMessage, isNull);
      expect(stt.transcriptions, 0);
      expect(container.read(speechModelReadyProvider), isFalse);

      // The download finishes and native says so.
      files.setModel(speech, ModelFileState.ready);
      files.emitChanged();
      await until(() => queue.pendingCount == 0);

      expect(container.read(speechModelReadyProvider), isTrue);
      expect(stt.transcriptions, 1);
      expect(queue.pendingCount, 0);
      expect((await notes.getAllNotes()), hasLength(1));
    });

    test('with the model already present a recording is transcribed at once', () async {
      files.setModel(speech, ModelFileState.ready);
      final queue = container.read(audioQueueServiceProvider);
      container.read(modelLibraryControllerProvider);
      await settle();

      await queue.enqueue('/audio/b.m4a');
      await until(() => queue.pendingCount == 0);

      expect(stt.transcriptions, 1);
      expect(queue.pendingCount, 0);
    });
  });

  group('manual synthesis without a writing model', () {
    testWidgets('says to choose a model and the action opens the setup screen', (tester) async {
      final files = FakeModelFilesChannel();
      final runner = _NoModelRunner();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          modelFilesChannelProvider.overrideWithValue(files),
          modelSettingsStoreProvider.overrideWithValue(InMemoryModelSettingsStore()),
          synthesisRunnerProvider.overrideWithValue(runner),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('start'),
                onPressed: () => startManualSynthesis(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(runner.runs, 1);
      expect(find.text('Choose a writing model first'), findsOneWidget);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(find.text('On-device models'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
