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
  /// Generated text with the `<|im_end|>`/`<|eot_id|>` stop markers and surrounding whitespace removed.
  final String text;

  /// Milliseconds from prompt submission to the first streamed chunk (0 if none arrived).
  final int timeToFirstTokenMs;
  final int totalMs;

  /// Streamed chunks received; one per generated token except tokens that end mid-character.
  final int outputChunks;

  /// True when the engine ended generation because `maxOutputTokens` was reached.
  final bool hitOutputCap;

  const LlmGeneration({
    required this.text,
    required this.timeToFirstTokenMs,
    required this.totalMs,
    required this.outputChunks,
    required this.hitOutputCap,
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

/// How the engine reported a prompt finished.
@immutable
class LlmPromptCompletion {
  /// True when generation ended because the prompt's `maxOutputTokens` was reached.
  final bool hitOutputCap;

  /// True when generation ended because [LlmPromptSession.stop] was requested.
  final bool stopped;

  const LlmPromptCompletion({required this.hitOutputCap, required this.stopped});
}

/// One prompt in flight on an [LlmEngine]. Only this prompt's chunks and completion are visible.
abstract class LlmPromptSession {
  /// Text chunks of this prompt only. Single-subscription; chunks are buffered until listened to.
  Stream<String> get chunks;

  /// Completes when the engine reports this prompt finished, including after [stop]. Completes
  /// with an error when generation failed.
  Future<LlmPromptCompletion> get completion;

  /// Asks the engine to end this prompt; [completion] then reports `stopped`.
  Future<void> stop();

  /// Detaches from this prompt; later chunks are dropped.
  Future<void> close();
}

/// Thin seam over the llama.cpp worker so [LLMService] is unit-testable.
abstract class LlmEngine {
  Future<void> load(String modelPath);

  /// Starts a generation from an empty context that ends after at most [maxOutputTokens] tokens.
  Future<LlmPromptSession> sendPrompt(String prompt, {required int maxOutputTokens});

  /// Frees the model and stops the worker; completes once nothing of it remains running.
  Future<void> dispose();
}

class LLMService {
  static const _stopMarkers = ['<|im_end|>', '<|eot_id|>'];

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
    // Reading a long prompt is one uninterruptible native call (tens of seconds on a phone), and
    // giving up means killing the worker without freeing the model, so wait well beyond it.
    this.stopTimeout = const Duration(minutes: 4),
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
    _logger?.info('[LLMService] Llama engine initialized successfully (context: ${config.kvCacheMaxSize}, type: ${config.kvCacheType.name}).');
  }

  /// Runs one stateless generation. [prompt] is the complete, already-formatted model prompt.
  ///
  /// Throws [StateError] when the model is not loaded or another generation is running,
  /// [TimeoutException] after [LLMConfig.generationTimeout], [LlmCancelledException] after
  /// [cancelActiveGeneration], and rethrows engine errors. In every early-exit case the
  /// engine is stopped and has reported completion before this returns or throws; if it
  /// never does, the service is disposed and [LlmEngineStuckException] is thrown.
  /// Partial text is never returned as success. The engine ends generation after
  /// [maxOutputTokens] tokens, reported through [LlmGeneration.hitOutputCap].
  Future<LlmGeneration> generate(String prompt, {required int maxOutputTokens}) async {
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
    final buffer = StringBuffer();
    final stopwatch = Stopwatch()..start();
    int? firstChunkMs;
    var chunkCount = 0;
    var hitCap = false;
    var accepting = true;
    LlmPromptSession? session;
    StreamSubscription<String>? chunkSub;

    try {
      session = await engine.sendPrompt(prompt, maxOutputTokens: maxOutputTokens);
      final active = session;
      chunkSub = active.chunks.listen((chunk) {
        if (!accepting) return;
        firstChunkMs ??= stopwatch.elapsedMilliseconds;
        chunkCount++;
        buffer.write(chunk);
      });

      Object? failure;
      LlmPromptCompletion? completion;
      try {
        final first = await Future.any<Object?>([active.completion, cancelRequested.future])
            .timeout(config.generationTimeout);
        if (first is LlmPromptCompletion) completion = first;
      } on TimeoutException catch (e) {
        _logger?.warning('[LLMService] Generation timed out after ${config.generationTimeout.inSeconds}s. Stopping.');
        failure = e;
      }
      // Chunks sent just before the completion event may still be queued on the stream.
      if (failure == null) await Future<void>.delayed(Duration.zero);
      if (failure == null && cancelRequested.isCompleted) failure = const LlmCancelledException();

      if (failure != null) {
        accepting = false;
        await _stopAndAwaitCompletion(active);
        throw failure;
      }
      hitCap = completion!.hitOutputCap;
    } finally {
      accepting = false;
      stopwatch.stop();
      await chunkSub?.cancel();
      try {
        await session?.close();
      } catch (e) {
        _logger?.warning('[LLMService] Error closing generation session: $e');
      }
      _activeIdle = null;
      _cancelRequested = null;
      idle.complete();
    }

    var text = buffer.toString();
    for (final marker in _stopMarkers) {
      text = text.split(marker).first;
    }
    return LlmGeneration(
      text: text.trim(),
      timeToFirstTokenMs: firstChunkMs ?? 0,
      totalMs: stopwatch.elapsedMilliseconds,
      outputChunks: chunkCount,
      hitOutputCap: hitCap,
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

