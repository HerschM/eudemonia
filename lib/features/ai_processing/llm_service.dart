import 'dart:async';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llama_isolate_engine.dart';
import 'llm_config.dart';

export 'llm_config.dart';

/// Result of one successful [LLMService.generate] call.
@immutable
class LlmGeneration {
  /// Generated text with surrounding whitespace removed.
  final String text;

  final int promptTokens;

  /// Prompt tokens whose memory was reused from the previous prompt.
  final int reusedPromptTokens;
  final int outputTokens;

  /// Milliseconds spent reading (tokenizing and decoding) the prompt.
  final int readMs;

  /// Milliseconds spent writing the reply.
  final int writeMs;

  /// Milliseconds from prompt submission to the reported completion.
  final int totalMs;

  /// True when the engine ended generation because `maxOutputTokens` was reached.
  final bool hitOutputCap;

  final int readingThreads;
  final int writingThreads;

  /// The cores the process was allowed to run on, such as `0-5`.
  final String allowedCores;

  const LlmGeneration({
    required this.text,
    required this.promptTokens,
    required this.reusedPromptTokens,
    required this.outputTokens,
    required this.readMs,
    required this.writeMs,
    required this.totalMs,
    required this.hitOutputCap,
    required this.readingThreads,
    required this.writingThreads,
    required this.allowedCores,
  });
}

/// Thrown by [LLMService.generate] when [LLMService.cancelActiveGeneration] ended it.
class LlmCancelledException implements Exception {
  const LlmCancelledException();
  @override
  String toString() => 'LlmCancelledException: generation was cancelled.';
}

/// Thrown when a stopped generation never reported completion; the service has disposed
/// the engine so the next use reloads the model.
class LlmEngineStuckException implements Exception {
  const LlmEngineStuckException();
  @override
  String toString() => 'LlmEngineStuckException: the language engine did not stop; it was disposed.';
}

/// How the engine reported a prompt finished: the whole reply and how it was produced.
@immutable
class LlmPromptCompletion {
  /// The reply text as generated (incomplete when [stopped]).
  final String text;

  /// True when generation ended because the prompt's `maxOutputTokens` was reached.
  final bool hitOutputCap;

  /// True when generation ended because [LlmPromptSession.stop] was requested.
  final bool stopped;

  final int promptTokens;
  final int reusedPromptTokens;
  final int outputTokens;
  final int readMs;
  final int writeMs;
  final int readingThreads;
  final int writingThreads;
  final String allowedCores;

  const LlmPromptCompletion({
    required this.text,
    required this.hitOutputCap,
    required this.stopped,
    this.promptTokens = 0,
    this.reusedPromptTokens = 0,
    this.outputTokens = 0,
    this.readMs = 0,
    this.writeMs = 0,
    this.readingThreads = 0,
    this.writingThreads = 0,
    this.allowedCores = '',
  });
}

/// One prompt in flight on an [LlmEngine]. Only this prompt's completion is visible.
abstract class LlmPromptSession {
  /// Completes when the engine reports this prompt finished, including after [stop]. Completes
  /// with an error when generation failed.
  Future<LlmPromptCompletion> get completion;

  /// Asks the engine to end this prompt; [completion] then reports `stopped`. The engine notices
  /// within one prompt chunk or one generated token.
  Future<void> stop();
}

/// Thin seam over the llama.cpp worker so [LLMService] is unit-testable.
abstract class LlmEngine {
  Future<void> load(String modelPath);

  /// Starts a generation that ends after at most [maxOutputTokens] tokens, constrained by the
  /// GBNF [grammar] when given. Its result never depends on earlier prompts.
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens, String? grammar});

  /// Frees the model and stops the worker; completes once nothing of it remains running.
  Future<void> dispose();
}

class LLMService {
  final LLMConfig config;
  final AppLogger? _logger;
  final LlmEngine Function() _engineFactory;

  /// How long a stopped prompt may take to report completion before the engine is declared stuck.
  final Duration stopTimeout;
  LlmEngine? _engine;
  bool _isInitialized = false;
  Future<void> _teardown = Future.value();

  /// Idle signal of the generation in flight; null when idle.
  Completer<void>? _activeIdle;
  Completer<void>? _cancelRequested;

  LLMService({
    this.config = const LLMConfig(),
    this._logger,
    LlmEngine Function()? engineFactory,
    // A stop is noticed after the prompt chunk or token being decoded (seconds on a phone even
    // when hot), and giving up means killing the worker without freeing the model.
    this.stopTimeout = const Duration(minutes: 1),
  }) : _engineFactory = engineFactory ?? (() => LlamaIsolateEngine(config, _logger));

  bool get isInitialized => _isInitialized;

  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;
    // Never hold two copies of the model: wait for a previous engine to free its weights.
    await _teardown;
    if (_isInitialized) return;

    _logger?.info('[LLMService] Initializing llama.cpp engine with config: $config');
    final engine = _engineFactory();
    await engine.load(modelPath);
    _engine = engine;
    _isInitialized = true;
    _logger?.info('[LLMService] Llama engine initialized successfully (context: ${config.kvCacheMaxSize}, '
        'chunk: ${config.promptChunkTokens}, prefix reuse: ${config.reusePromptPrefix}).');
  }

  /// Runs one generation whose result never depends on earlier calls. [prompt] is the complete,
  /// already-formatted model prompt; [grammar] (GBNF) constrains the reply when given.
  ///
  /// Throws [StateError] when the model is not loaded or another generation is running,
  /// [TimeoutException] after [LLMConfig.generationTimeout], [LlmCancelledException] after
  /// [cancelActiveGeneration] (or when the engine reports the prompt stopped for any other
  /// reason), and rethrows engine errors. In every early-exit case the engine is stopped and
  /// has reported completion before this returns or throws; if it never does, the service is
  /// disposed and [LlmEngineStuckException] is thrown. Partial text is never returned as
  /// success. The engine ends generation after [maxOutputTokens] tokens, reported through
  /// [LlmGeneration.hitOutputCap].
  Future<LlmGeneration> generate(String prompt, {required int maxOutputTokens, String? grammar}) async {
    final engine = _engine;
    if (!_isInitialized || engine == null) {
      throw StateError('LLMService.generate called before the model was loaded.');
    }
    if (_activeIdle != null) {
      throw StateError('LLMService.generate called while another generation is running.');
    }
    if (maxOutputTokens <= 0) {
      throw ArgumentError.value(maxOutputTokens, 'maxOutputTokens', 'must be positive');
    }

    final idle = _activeIdle = Completer<void>();
    final cancelRequested = _cancelRequested = Completer<void>();
    final stopwatch = Stopwatch()..start();
    LlmPromptCompletion completion;

    try {
      final session = await engine.sendPrompt(prompt, maxOutputTokens: maxOutputTokens, grammar: grammar);

      Object? failure;
      LlmPromptCompletion? done;
      try {
        final first = await Future.any<Object?>([session.completion, cancelRequested.future])
            .timeout(config.generationTimeout);
        if (first is LlmPromptCompletion) done = first;
      } on TimeoutException catch (e) {
        _logger?.warning('[LLMService] Generation timed out after ${config.generationTimeout.inSeconds}s. Stopping.');
        failure = e;
      }
      if (failure == null && cancelRequested.isCompleted) failure = const LlmCancelledException();
      // A prompt stopped by anything but this call (the engine being disposed) ended mid-reply.
      if (failure == null && done!.stopped) failure = const LlmCancelledException();

      if (failure != null) {
        await _stopAndAwaitCompletion(session);
        throw failure;
      }
      completion = done!;
    } finally {
      stopwatch.stop();
      _activeIdle = null;
      _cancelRequested = null;
      idle.complete();
    }

    return LlmGeneration(
      text: completion.text.trim(),
      promptTokens: completion.promptTokens,
      reusedPromptTokens: completion.reusedPromptTokens,
      outputTokens: completion.outputTokens,
      readMs: completion.readMs,
      writeMs: completion.writeMs,
      totalMs: stopwatch.elapsedMilliseconds,
      hitOutputCap: completion.hitOutputCap,
      readingThreads: completion.readingThreads,
      writingThreads: completion.writingThreads,
      allowedCores: completion.allowedCores,
    );
  }

  /// Stops [session] and waits for the engine to report it finished. If it does not within
  /// [stopTimeout] the engine is disposed and [LlmEngineStuckException] is thrown.
  Future<void> _stopAndAwaitCompletion(LlmPromptSession session) async {
    try {
      await session.stop();
    } catch (e) {
      _logger?.warning('[LLMService] Error stopping generation: $e');
    }
    try {
      await session.completion.timeout(stopTimeout);
    } catch (e) {
      _logger?.warning('[LLMService] Engine did not report completion after stop ($e). Disposing it.');
      await dispose();
      throw const LlmEngineStuckException();
    }
  }

  /// Stops the generation in flight, if any, and completes once the engine is idle again.
  /// That [generate] call throws [LlmCancelledException]. No-op when idle.
  Future<void> cancelActiveGeneration() async {
    final idle = _activeIdle;
    if (idle == null) return;
    final cancel = _cancelRequested;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    await idle.future;
  }

  /// Frees the model. Completes once the engine is fully disposed; concurrent callers share
  /// the same wait, so a caller never proceeds while the weights are still resident.
  Future<void> dispose() {
    final engine = _engine;
    _engine = null;
    _isInitialized = false;
    if (engine != null) _teardown = _disposeEngine(engine);
    return _teardown;
  }

  Future<void> _disposeEngine(LlmEngine engine) async {
    _logger?.info('[LLMService] Disposing LLMService...');
    try {
      await engine.dispose();
    } catch (e) {
      _logger?.warning('[LLMService] Error disposing engine: $e');
    }
    _logger?.info('[LLMService] LLMService disposed. Base weights and KV cache freed.');
  }
}

final llmServiceProvider = Provider<LLMService>((ref) {
  final config = ref.watch(llmConfigProvider);
  final logger = ref.watch(appLoggerProvider);
  return LLMService(config: config, logger: logger);
});
