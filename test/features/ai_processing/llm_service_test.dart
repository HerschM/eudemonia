import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';

class FakeSession implements LlmPromptSession {
  final Completer<LlmPromptCompletion> _completion = Completer<LlmPromptCompletion>();
  final String prompt;
  final int maxOutputTokens;
  final String? grammar;
  int stopCalls = 0;

  /// When true, stop() makes the fake report completion; otherwise it never does.
  bool completeOnStop = true;

  FakeSession(this.prompt, this.maxOutputTokens, this.grammar);

  @override
  Future<LlmPromptCompletion> get completion => _completion.future;

  bool get isFinished => _completion.isCompleted;

  void finish(String text, {bool hitOutputCap = false, bool stopped = false, int outputTokens = 0}) {
    if (!_completion.isCompleted) {
      _completion.complete(LlmPromptCompletion(
          text: text, hitOutputCap: hitOutputCap, stopped: stopped, outputTokens: outputTokens));
    }
  }

  void finishWith(LlmPromptCompletion completion) {
    if (!_completion.isCompleted) _completion.complete(completion);
  }

  void fail(Object error) {
    if (!_completion.isCompleted) _completion.completeError(error);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (completeOnStop) Future<void>.delayed(const Duration(milliseconds: 5), () => finish('partial', stopped: true));
  }
}

class FakeEngine implements LlmEngine {
  final List<FakeSession> sessions = [];
  bool loaded = false;
  bool disposed = false;
  bool completeOnStop = true;
  void Function(FakeSession)? onSession;

  @override
  Future<void> load(String modelPath) async => loaded = true;

  @override
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens, String? grammar}) async {
    if (!loaded) throw StateError('fake engine used before load');
    final s = FakeSession(prompt, maxOutputTokens, grammar)..completeOnStop = completeOnStop;
    sessions.add(s);
    // Let generate() wait on the completion before the script runs.
    Future<void>.delayed(Duration.zero, () => onSession?.call(s));
    return s;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    loaded = false;
  }
}

void main() {
  late FakeEngine engine;

  Future<LLMService> make({LLMConfig config = const LLMConfig(), Duration stopTimeout = const Duration(milliseconds: 100)}) async {
    final s = LLMService(config: config, engineFactory: () => engine, stopTimeout: stopTimeout);
    await s.initialize('/fake');
    return s;
  }

  setUp(() => engine = FakeEngine());

  group('LLMService with a fake engine', () {
    test('before the model is loaded generate throws StateError', () async {
      final s = LLMService(engineFactory: () => engine);
      await expectLater(s.generate('p', maxOutputTokens: 4), throwsA(isA<StateError>()));
    });

    test('after dispose generate throws StateError', () async {
      final s = await make();
      await s.dispose();
      expect(engine.disposed, isTrue);
      await expectLater(s.generate('p', maxOutputTokens: 4), throwsA(isA<StateError>()));
    });

    test('a stop waits up to one minute by default (one prompt chunk on a hot phone)', () {
      expect(LLMService(engineFactory: () => engine).stopTimeout, const Duration(minutes: 1));
    });

    test('normal completion returns the trimmed text and the engine figures, without a stop', () async {
      engine.onSession = (s) => s.finishWith(const LlmPromptCompletion(
            text: ' hello world \n',
            hitOutputCap: false,
            stopped: false,
            promptTokens: 300,
            reusedPromptTokens: 256,
            outputTokens: 2,
            readMs: 1200,
            writeMs: 400,
            readingThreads: 6,
            writingThreads: 2,
            allowedCores: '0-5',
          ));
      final s = await make();
      final g = await s.generate('p', maxOutputTokens: 10);
      expect(g.text, 'hello world');
      expect(g.hitOutputCap, isFalse);
      expect((g.promptTokens, g.reusedPromptTokens, g.outputTokens), (300, 256, 2));
      expect((g.readMs, g.writeMs), (1200, 400));
      expect((g.readingThreads, g.writingThreads, g.allowedCores), (6, 2, '0-5'));
      expect(g.totalMs, greaterThanOrEqualTo(0));
      expect(engine.sessions.single.stopCalls, 0);
    });

    test('the prompt, the cap and the grammar are passed to the engine', () async {
      engine.onSession = (s) => s.finish('1: Work');
      final s = await make();
      await s.generate('organise', maxOutputTokens: 16, grammar: 'root ::= "1: Work"');
      await s.generate('write', maxOutputTokens: 200);
      final [organise, write] = engine.sessions;
      expect((organise.prompt, organise.maxOutputTokens, organise.grammar), ('organise', 16, 'root ::= "1: Work"'));
      expect((write.prompt, write.maxOutputTokens, write.grammar), ('write', 200, null));
    });

    test('the cap is passed to the engine and reported from its completion, without a stop', () async {
      engine.onSession = (s) => s.finish('aaa', hitOutputCap: true, outputTokens: s.maxOutputTokens);
      final s = await make();
      final g = await s.generate('p', maxOutputTokens: 3);
      expect(g.hitOutputCap, isTrue);
      expect(g.outputTokens, 3);
      expect(g.text, 'aaa');
      final session = engine.sessions.single;
      expect(session.maxOutputTokens, 3);
      expect(session.stopCalls, 0);
      expect(engine.disposed, isFalse);
    });

    test('an engine error completion is rethrown and partial text is not returned', () async {
      engine.onSession = (s) => s.fail(Exception('native fault'));
      final s = await make();
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<Exception>()));
      // Idle again afterwards.
      engine.onSession = (s) => s.finish('ok');
      expect((await s.generate('p', maxOutputTokens: 10)).text, 'ok');
    });

    test('a prompt the engine reports as stopped is not returned as success', () async {
      engine.onSession = (s) => s.finish('half a rep', stopped: true);
      final s = await make();
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<LlmCancelledException>()));
      expect(engine.disposed, isFalse);
    });

    test('the reply of one prompt never reaches the next call', () async {
      var call = 0;
      engine.onSession = (s) {
        call++;
        if (call == 1) {
          s.finish('old', hitOutputCap: true);
          // A late report for the old prompt arrives while the next one runs.
          Future<void>.delayed(const Duration(milliseconds: 2), () => s.finish('LEAK'));
        } else {
          Future<void>.delayed(const Duration(milliseconds: 5), () => s.finish('new'));
        }
      };
      final s = await make();
      final first = await s.generate('p1', maxOutputTokens: 3);
      expect(first.text, 'old');
      final second = await s.generate('p2', maxOutputTokens: 10);
      expect(second.text, 'new');
    });

    test('timeout stops the engine then throws TimeoutException', () async {
      final s = await make(config: const LLMConfig(generationTimeout: Duration(milliseconds: 30)));
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<TimeoutException>()));
      final session = engine.sessions.single;
      expect(session.stopCalls, 1);
      // The engine reported the stopped prompt before generate threw.
      expect(session.isFinished, isTrue);
      expect(engine.disposed, isFalse);
    });

    test('an engine that never completes after stop is disposed and reported stuck', () async {
      engine.completeOnStop = false;
      final s = await make(config: const LLMConfig(generationTimeout: Duration(milliseconds: 30)));
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<LlmEngineStuckException>()));
      // The engine (and its isolate) is fully disposed before the exception surfaces.
      expect(engine.disposed, isTrue);
      expect(s.isInitialized, isFalse);
    });

    test('cancelActiveGeneration stops cleanly and the generate call throws LlmCancelledException', () async {
      final s = await make();
      final gen = s.generate('p', maxOutputTokens: 10);
      final expectation = expectLater(gen, throwsA(isA<LlmCancelledException>()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await s.cancelActiveGeneration();
      await expectation;
      expect(engine.sessions.single.stopCalls, 1);
      expect(engine.sessions.single.isFinished, isTrue);
      // Idle again: a new generation is allowed and cancel is a no-op.
      await s.cancelActiveGeneration();
      engine.onSession = (s) => s.finish('ok');
      expect((await s.generate('p', maxOutputTokens: 10)).text, 'ok');
    });

    test('the text is returned as the engine generated it, apart from surrounding whitespace', () async {
      // Stop markers are end-of-generation tokens: the engine ends the reply and never renders them.
      engine.onSession = (s) => s.finish('  keep <b>this</b>\n\n');
      final s = await make();
      expect((await s.generate('p', maxOutputTokens: 10)).text, 'keep <b>this</b>');
    });

    test('a concurrent generate call is rejected with StateError', () async {
      final s = await make();
      final first = expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<LlmCancelledException>()));
      await expectLater(s.generate('q', maxOutputTokens: 10), throwsA(isA<StateError>()));
      await s.cancelActiveGeneration();
      await first;
    });

    test('a non-positive cap is rejected before anything is sent', () async {
      final s = await make();
      await expectLater(s.generate('p', maxOutputTokens: 0), throwsArgumentError);
      expect(engine.sessions, isEmpty);
    });
  });

  group('LLMService residency for the status sheet', () {
    test('reports loading, then loaded, then unloaded only once the weights are freed', () async {
      final states = <ModelLifecycleState>[];
      final gate = Completer<void>();
      final slow = _GatedDisposeEngine(gate.future);
      final s = LLMService(engineFactory: () => slow, onStateChanged: states.add);

      await s.initialize('/fake');
      expect(states, [ModelLifecycleState.loading, ModelLifecycleState.ready]);

      final disposing = s.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(states.last, ModelLifecycleState.ready, reason: 'still in memory while it is being freed');
      gate.complete();
      await disposing;
      expect(states, [ModelLifecycleState.loading, ModelLifecycleState.ready, ModelLifecycleState.unloaded]);
    });

    test('a load that fails reports unloaded', () async {
      final states = <ModelLifecycleState>[];
      final s = LLMService(engineFactory: () => _FailingLoadEngine(), onStateChanged: states.add);

      await expectLater(s.initialize('/fake'), throwsStateError);

      expect(states, [ModelLifecycleState.loading, ModelLifecycleState.unloaded]);
      expect(s.isInitialized, isFalse);
    });
  });
}

class _GatedDisposeEngine extends FakeEngine {
  final Future<void> gate;

  _GatedDisposeEngine(this.gate);

  @override
  Future<void> dispose() async {
    await gate;
    await super.dispose();
  }
}

class _FailingLoadEngine extends FakeEngine {
  @override
  Future<void> load(String modelPath) async => throw StateError('corrupt model file');
}
