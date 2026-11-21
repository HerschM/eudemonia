import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_config.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';

class FakeSTTService extends STTService {
  int initializeCallCount = 0;
  int disposeCallCount = 0;
  bool _mockInitialized = false;
  Completer<void>? initializeGate;
  bool failInitialize = false;

  @override
  bool get isInitialized => _mockInitialized;

  @override
  Future<void> initialize(String modelDir) async {
    initializeCallCount++;
    if (initializeGate != null) await initializeGate!.future;
    if (failInitialize) throw Exception('STT model not found at $modelDir');
    _mockInitialized = true;
  }

  @override
  void dispose() {
    disposeCallCount++;
    _mockInitialized = false;
  }
}

void main() {
  group('ModelLifecycleManager', () {
    late FakeSTTService fakeSTT;
    late ModelLifecycleManager manager;

    setUp(() {
      fakeSTT = FakeSTTService();
      manager = ModelLifecycleManager(
        fakeSTT,
        config: const LLMConfig(
          modelInactivityTtl: Duration(minutes: 3),
        ),
        modelsDirResolver: () async => '/mock/models/dir',
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test('initial state is unloaded and models are not resident in RAM', () {
      expect(manager.state, equals(ModelLifecycleState.unloaded));
      expect(manager.areModelsLoaded, isFalse);
      expect(fakeSTT.initializeCallCount, equals(0));
    });

    test('ensureModelsLoaded loads the speech model and transitions state to ready', () async {
      await manager.ensureModelsLoaded(reason: 'unit test load');

      expect(manager.state, equals(ModelLifecycleState.ready));
      expect(manager.areModelsLoaded, isTrue);
      expect(fakeSTT.initializeCallCount, equals(1));
      expect(fakeSTT.isInitialized, isTrue);
    });

    test('ensureModelsLoaded is idempotent and skips reloading when already ready', () async {
      await manager.ensureModelsLoaded(reason: 'first call');
      await manager.ensureModelsLoaded(reason: 'second call');

      expect(manager.state, equals(ModelLifecycleState.ready));
      expect(fakeSTT.initializeCallCount, equals(1));
    });

    test('concurrent calls to ensureModelsLoaded share single loading future', () async {
      final future1 = manager.ensureModelsLoaded(reason: 'concurrent 1');
      final future2 = manager.ensureModelsLoaded(reason: 'concurrent 2');

      await Future.wait([future1, future2]);

      expect(manager.state, equals(ModelLifecycleState.ready));
      expect(fakeSTT.initializeCallCount, equals(1));
    });

    test('warmupOnRecordingStart triggers asynchronous model loading', () async {
      manager.warmupOnRecordingStart();

      // Yield event loop
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, equals(ModelLifecycleState.ready));
      expect(fakeSTT.initializeCallCount, equals(1));
    });

    testWidgets('inactivity TTL timer evicts models after configured idle duration', (tester) async {
      await manager.ensureModelsLoaded();
      expect(manager.areModelsLoaded, isTrue);

      // Call touch() to simulate activity completion (e.g. note processed)
      manager.touch(reason: 'note processed');

      // Advance time by 2 minutes (less than 3-minute TTL)
      await tester.pump(const Duration(minutes: 2));
      expect(manager.areModelsLoaded, isTrue);
      expect(fakeSTT.disposeCallCount, equals(0));

      // Advance past 3 minutes
      await tester.pump(const Duration(minutes: 1, seconds: 1));

      expect(manager.state, equals(ModelLifecycleState.unloaded));
      expect(manager.areModelsLoaded, isFalse);
      expect(fakeSTT.disposeCallCount, equals(1));
    });

    testWidgets('new activity resets the inactivity timer and prevents eviction', (tester) async {
      await manager.ensureModelsLoaded();
      manager.touch(reason: 'initial note');

      // Advance 2 minutes
      await tester.pump(const Duration(minutes: 2));

      // Touch again (user records another note)
      manager.touch(reason: 'second note');

      // Advance another 2 minutes (4 minutes total, but only 2m since last touch)
      await tester.pump(const Duration(minutes: 2));
      expect(manager.areModelsLoaded, isTrue);
      expect(fakeSTT.disposeCallCount, equals(0));

      // Advance final 1m1s to expire second timer
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(manager.areModelsLoaded, isFalse);
      expect(fakeSTT.disposeCallCount, equals(1));
    });

    test('models can be reloaded cleanly on-demand after eviction', () async {
      await manager.ensureModelsLoaded(reason: 'initial');
      expect(manager.areModelsLoaded, isTrue);

      await manager.evictModels(reason: 'manual eviction');
      expect(manager.state, equals(ModelLifecycleState.unloaded));
      expect(fakeSTT.disposeCallCount, equals(1));

      // Reload
      await manager.ensureModelsLoaded(reason: 'reload after eviction');
      expect(manager.state, equals(ModelLifecycleState.ready));
      expect(fakeSTT.initializeCallCount, equals(2));
    });

    test('loads and evicts only the STT service, and loading needs no LLM file', () async {
      // '/mock/models/dir' holds no GGUF and no validator is wired, so any LLM
      // dependency would surface here as a failed load.
      await manager.ensureModelsLoaded(reason: 'stt only');
      expect(manager.state, equals(ModelLifecycleState.ready));
      expect(fakeSTT.initializeCallCount, equals(1));

      await manager.evictModels(reason: 'stt only');
      expect(manager.state, equals(ModelLifecycleState.unloaded));
      expect(fakeSTT.disposeCallCount, equals(1));
    });

    test('diagnostic state dump contains valid telemetry information', () async {
      await manager.ensureModelsLoaded(reason: 'telemetry test');
      final dump = manager.getDiagnosticState();

      expect(dump['state'], equals('ready'));
      expect(dump['isSTTInitialized'], isTrue);
      expect(dump['inactivityTtlMinutes'], equals(3));
      expect(dump.containsKey('isLLMInitialized'), isFalse);
      expect(dump.containsKey('kvCacheMaxSize'), isFalse);
      expect(dump['lastLoadedTime'], isNotNull);
    });

    group('load failure & eviction safety', () {
      test('a failed STT load leaves the manager unloaded and disposes the handle', () async {
        fakeSTT.failInitialize = true;

        await expectLater(manager.ensureModelsLoaded(), throwsException);

        expect(manager.state, equals(ModelLifecycleState.unloaded));
        expect(fakeSTT.isInitialized, isFalse);
        expect(fakeSTT.disposeCallCount, equals(1));
      });

      test('every concurrent caller observes a load failure and a retry can succeed', () async {
        fakeSTT.failInitialize = true;

        final first = manager.ensureModelsLoaded(reason: 'first');
        final second = manager.ensureModelsLoaded(reason: 'second');
        await expectLater(first, throwsException);
        await expectLater(second, throwsException);
        expect(fakeSTT.initializeCallCount, equals(1));

        fakeSTT.failInitialize = false;
        await manager.ensureModelsLoaded(reason: 'retry');
        expect(manager.state, equals(ModelLifecycleState.ready));
      });

      test('eviction requested during inference is deferred until the task completes', () async {
        final taskGate = Completer<void>();
        final task = manager.runWithModels(() => taskGate.future);
        await Future<void>.delayed(Duration.zero);
        expect(manager.state, equals(ModelLifecycleState.ready));

        final evicted = await manager.evictModels(reason: 'manual');
        expect(evicted, isFalse);
        expect(manager.state, equals(ModelLifecycleState.ready));
        expect(fakeSTT.disposeCallCount, equals(0));

        taskGate.complete();
        await task;

        expect(manager.state, equals(ModelLifecycleState.unloaded));
        expect(fakeSTT.disposeCallCount, equals(1));
      });

      test('eviction requested while loading waits for the load, then unloads', () async {
        fakeSTT.initializeGate = Completer<void>();
        final loading = manager.ensureModelsLoaded();
        expect(manager.state, equals(ModelLifecycleState.loading));

        final eviction = manager.evictModels(reason: 'manual');
        fakeSTT.initializeGate!.complete();
        await loading;

        expect(await eviction, isTrue);
        expect(manager.state, equals(ModelLifecycleState.unloaded));
        expect(fakeSTT.isInitialized, isFalse);
      });

      test('runWithModels restarts the inactivity countdown even when the task throws', () async {
        await expectLater(
          manager.runWithModels<void>(() async => throw Exception('inference failed')),
          throwsException,
        );

        expect(manager.state, equals(ModelLifecycleState.ready));
        expect(manager.getDiagnosticState()['isTimerActive'], isTrue);
      });

      test('state transitions are reported to the onStateChanged listener', () async {
        final transitions = <ModelLifecycleState>[];
        final observed = ModelLifecycleManager(
          fakeSTT,
          modelsDirResolver: () async => '/mock/models/dir',
          onStateChanged: transitions.add,
        );

        await observed.ensureModelsLoaded();
        await observed.evictModels();

        expect(transitions, [
          ModelLifecycleState.loading,
          ModelLifecycleState.ready,
          ModelLifecycleState.unloaded,
        ]);
      });
    });
  });
}
