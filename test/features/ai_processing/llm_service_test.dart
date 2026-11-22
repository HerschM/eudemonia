import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';

class FakeSession implements LlmPromptSession {
  final StreamController<String> _chunks = StreamController<String>();
  final Completer<LlmPromptCompletion> _completion = Completer<LlmPromptCompletion>();
  final int maxOutputTokens;
  int stopCalls = 0;
  bool closed = false;

  /// When true, stop() makes the fake report completion; otherwise it never does.
  bool completeOnStop = true;

  FakeSession(this.maxOutputTokens);

  @override
  Stream<String> get chunks => _chunks.stream;
  @override
  Future<LlmPromptCompletion> get completion => _completion.future;

  void emit(String c) => _chunks.add(c);
  void finish({bool hitOutputCap = false, bool stopped = false}) {
    if (!_completion.isCompleted) {
      _completion.complete(LlmPromptCompletion(hitOutputCap: hitOutputCap, stopped: stopped));
    }
  }

  void fail(Object error) {
    if (!_completion.isCompleted) _completion.completeError(error);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (completeOnStop) Future<void>.delayed(const Duration(milliseconds: 5), () => finish(stopped: true));
  }

  @override
  Future<void> close() async {
    closed = true;
    await _chunks.close();
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
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens}) async {
    if (!loaded) throw StateError('fake engine used before load');
    final s = FakeSession(maxOutputTokens)..completeOnStop = completeOnStop;
    sessions.add(s);
    // Let generate() subscribe before the script runs.
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

    test('normal completion returns trimmed text and closes the session', () async {
      engine.onSession = (s) {
        s.emit(' hello');
        s.emit(' world ');
        s.finish();
      };
      final s = await make();
      final g = await s.generate('p', maxOutputTokens: 10);
      expect(g.text, 'hello world');
      expect(g.outputChunks, 2);
      expect(g.hitOutputCap, isFalse);
      expect(engine.sessions.single.stopCalls, 0);
      expect(engine.sessions.single.closed, isTrue);
    });

    test('the cap is passed to the engine and reported from its completion, without a stop', () async {
      engine.onSession = (s) {
        for (var i = 0; i < s.maxOutputTokens; i++) {
          s.emit('a');
        }
        s.finish(hitOutputCap: true);
      };
      final s = await make();
      final g = await s.generate('p', maxOutputTokens: 3);
      expect(g.hitOutputCap, isTrue);
      expect(g.outputChunks, 3);
      expect(g.text, 'aaa');
      final session = engine.sessions.single;
      expect(session.maxOutputTokens, 3);
      expect(session.stopCalls, 0);
      expect(engine.disposed, isFalse);
    });

    test('an engine error completion is rethrown and partial text is not returned', () async {
      engine.onSession = (s) {
        s.emit('partial');
        s.fail(Exception('native fault'));
      };
      final s = await make();
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<Exception>()));
      expect(engine.sessions.single.closed, isTrue);
    });

    test('chunks emitted after the cap for the old prompt do not leak into the next call', () async {
      var call = 0;
      engine.onSession = (s) {
        call++;
        if (call == 1) {
          for (var i = 0; i < 3; i++) {
            s.emit('old');
          }
          s.finish(hitOutputCap: true);
          // Leftovers arrive while the engine is stopping.
          Future<void>.delayed(const Duration(milliseconds: 2), () {
            if (!s.closed) s.emit('LEAK');
          });
        } else {
          s.emit('new');
          s.finish();
        }
      };
      final s = await make();
      final first = await s.generate('p1', maxOutputTokens: 3);
      expect(first.text, 'oldoldold');
      final second = await s.generate('p2', maxOutputTokens: 10);
      expect(second.text, 'new');
    });

    test('timeout stops the engine then throws TimeoutException', () async {
      engine.onSession = (s) => s.emit('x');
      final s = await make(config: const LLMConfig(generationTimeout: Duration(milliseconds: 30)));
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<TimeoutException>()));
      expect(engine.sessions.single.stopCalls, 1);
      expect(engine.sessions.single.closed, isTrue);
      expect(engine.disposed, isFalse);
    });

    test('an engine that never completes after stop is disposed and reported stuck', () async {
      engine.completeOnStop = false;
      engine.onSession = (s) => s.emit('x');
      final s = await make(config: const LLMConfig(generationTimeout: Duration(milliseconds: 30)));
      await expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<LlmEngineStuckException>()));
      // The engine (and its isolate) is fully disposed before the exception surfaces.
      expect(engine.disposed, isTrue);
      expect(s.isInitialized, isFalse);
    });

    test('cancelActiveGeneration stops cleanly and the generate call throws LlmCancelledException', () async {
      engine.onSession = (s) => s.emit('x');
      final s = await make();
      final gen = s.generate('p', maxOutputTokens: 10);
      final expectation = expectLater(gen, throwsA(isA<LlmCancelledException>()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await s.cancelActiveGeneration();
      await expectation;
      expect(engine.sessions.single.stopCalls, 1);
      // Idle again: a new generation is allowed and cancel is a no-op.
      await s.cancelActiveGeneration();
      engine.onSession = (s) {
        s.emit('ok');
        s.finish();
      };
      expect((await s.generate('p', maxOutputTokens: 10)).text, 'ok');
    });

    test('both stop markers cut the output', () async {
      for (final marker in ['<|im_end|>', '<|eot_id|>']) {
        engine = FakeEngine()
          ..onSession = (s) {
            s.emit('keep');
            s.emit(marker);
            s.emit('drop');
            s.finish();
          };
        final s = await make();
        expect((await s.generate('p', maxOutputTokens: 10)).text, 'keep', reason: marker);
      }
    });

    test('a concurrent generate call is rejected with StateError', () async {
      engine.onSession = (s) => s.emit('x');
      final s = await make();
      final first = expectLater(s.generate('p', maxOutputTokens: 10), throwsA(isA<LlmCancelledException>()));
      await expectLater(s.generate('q', maxOutputTokens: 10), throwsA(isA<StateError>()));
      await s.cancelActiveGeneration();
      await first;
    });
  });
}
