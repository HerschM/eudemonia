import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llm_config.dart';

export 'llm_config.dart';

/// Result of one successful [LLMService.generate] call.
@immutable
class LlmGeneration {
  /// Generated text with the `<|im_end|>` stop marker and surrounding whitespace removed.
  final String text;

  /// Milliseconds from prompt submission to the first streamed chunk (0 if none arrived).
  final int timeToFirstTokenMs;
  final int totalMs;

  /// Streamed chunks received; one per generated token except tokens that end mid-character.
  final int outputChunks;

  /// True when generation was stopped because `maxOutputTokens` was reached.
  final bool hitOutputCap;

  const LlmGeneration({
    required this.text,
    required this.timeToFirstTokenMs,
    required this.totalMs,
    required this.outputChunks,
    required this.hitOutputCap,
  });
}

class LLMService {
  static const _stopMarker = '<|im_end|>';

  final LLMConfig config;
  final AppLogger? _logger;
  LlamaParent? _llama;
  bool _isInitialized = false;

  LLMService({this.config = const LLMConfig(), this._logger});

  bool get isInitialized => _isInitialized;

  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;

    if (!await File(modelPath).exists()) {
      throw Exception('LLM model not found at $modelPath');
    }

    _logger?.info('[LLMService] Initializing llama.cpp engine with config: $config');

    final contextParams = ContextParams()
      ..nCtx = config.kvCacheMaxSize
      // The binding rejects any prompt longer than nBatch, so the batch must span the context.
      ..nBatch = max(config.batchSize, config.kvCacheMaxSize)
      // The binding fixes nPredict at load time; -1 is unlimited. The per-call cap is
      // enforced in generate() by counting streamed chunks.
      ..nPredict = -1
      ..nThreads = config.threads
      ..nThreadsBatch = config.threads
      ..typeK = config.kvCacheType
      ..typeV = config.kvCacheType;

    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: ModelParams()..nGpuLayers = config.gpuLayers,
      contextParams: contextParams,
      samplingParams: SamplerParams()..greedy = config.greedySampling,
    );

    final parent = LlamaParent(loadCommand);
    try {
      await parent.init();
    } on TimeoutException {
      // The library stops waiting after 60s, but its isolate is still loading the model.
      // Abandoning it here would fail the thought and leave a second load running.
      _logger?.warning('[LLMService] Model load exceeded the library limit; still loading, waiting up to '
          '${config.modelLoadTimeout.inSeconds}s in total.');
      await _awaitLoadCompletion(parent, alreadyWaited: const Duration(seconds: 60));
    } catch (_) {
      parent.dispose();
      rethrow;
    }
    _llama = parent;
    _isInitialized = true;
    _logger?.info('[LLMService] Llama engine initialized successfully (context: ${config.kvCacheMaxSize}, type: ${config.kvCacheType.name}).');
  }

  /// Waits for an in-flight model load to report ready. Disposes [parent] and throws if it
  /// reports an error or does not finish within [LLMConfig.modelLoadTimeout].
  Future<void> _awaitLoadCompletion(LlamaParent parent, {required Duration alreadyWaited}) async {
    final waited = Stopwatch()..start();
    while (parent.status != LlamaStatus.ready) {
      final failed = parent.status == LlamaStatus.error || parent.status == LlamaStatus.disposed;
      if (failed || alreadyWaited + waited.elapsed >= config.modelLoadTimeout) {
        parent.dispose();
        throw Exception(failed
            ? 'The language model failed to load.'
            : 'The language model did not finish loading within ${config.modelLoadTimeout.inSeconds} seconds.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Runs one stateless generation. [prompt] is the complete, already-formatted model prompt.
  ///
  /// Throws [StateError] when the model is not loaded, [TimeoutException] after
  /// [LLMConfig.generationTimeout] (generation is stopped first), and rethrows engine errors.
  /// Partial text is never returned as success. Generation also ends at [maxOutputTokens]
  /// streamed chunks, reported through [LlmGeneration.hitOutputCap].
  Future<LlmGeneration> generate(String prompt, {required int maxOutputTokens}) async {
    final llama = _llama;
    if (!_isInitialized || llama == null) {
      throw StateError('LLMService.generate called before the model was loaded.');
    }
    if (maxOutputTokens <= 0) {
      throw ArgumentError.value(maxOutputTokens, 'maxOutputTokens', 'must be positive');
    }

    final buffer = StringBuffer();
    final stopwatch = Stopwatch()..start();
    int? firstChunkMs;
    var chunkCount = 0;
    var hitCap = false;
    final capReached = Completer<void>();
    // Each call gets its own scope, disposed afterwards, so no context carries over (AGENTS.md 4.C).
    final scope = llama.getScope() as LlamaScope;
    final streamSub = llama.stream.listen((chunk) {
      if (hitCap) return;
      firstChunkMs ??= stopwatch.elapsedMilliseconds;
      chunkCount++;
      buffer.write(chunk);
      if (chunkCount >= maxOutputTokens) {
        hitCap = true;
        capReached.complete();
      }
    });

    try {
      final promptId = await llama.sendPrompt(prompt, scope: scope);
      final completed = llama.completions.firstWhere((e) => e.promptId == promptId);
      completed.ignore(); // the cap path leaves it unawaited
      try {
        await Future.any<Object?>([completed, capReached.future]).timeout(config.generationTimeout);
      } on TimeoutException {
        _logger?.warning('[LLMService] Generation timed out after ${config.generationTimeout.inSeconds}s. Stopping.');
        await _stopQuietly(llama);
        rethrow;
      }
      if (hitCap) await _stopQuietly(llama);
    } finally {
      stopwatch.stop();
      await streamSub.cancel();
      try {
        await llama.disposeScope(scope);
      } catch (e) {
        _logger?.warning('[LLMService] Error disposing generation scope: $e');
      }
    }

    final text = buffer.toString().split(_stopMarker).first.trim();
    return LlmGeneration(
      text: text,
      timeToFirstTokenMs: firstChunkMs ?? 0,
      totalMs: stopwatch.elapsedMilliseconds,
      outputChunks: chunkCount,
      hitOutputCap: hitCap,
    );
  }

  Future<void> _stopQuietly(LlamaParent llama) async {
    try {
      await llama.stop();
    } catch (e) {
      _logger?.warning('[LLMService] Error stopping generation: $e');
    }
  }

  void dispose() {
    _logger?.info('[LLMService] Disposing LLMService...');
    _llama?.dispose();
    _llama = null;
    _isInitialized = false;
    _logger?.info('[LLMService] LLMService disposed. Base weights and KV cache freed.');
  }
}

final llmServiceProvider = Provider<LLMService>((ref) {
  final config = ref.watch(llmConfigProvider);
  final logger = ref.watch(appLoggerProvider);
  return LLMService(config: config, logger: logger);
});

