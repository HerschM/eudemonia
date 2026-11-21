import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llm_config.dart';

export 'llm_config.dart';

class LLMService {
  final LLMConfig config;
  final AppLogger? _logger;
  LlamaParent? _llama;
  bool _isInitialized = false;

  LlamaScope? _currentScope;

  LLMService({this.config = const LLMConfig(), this._logger});

  bool get isInitialized => _isInitialized;
  bool get hasActiveKvScope => _currentScope != null;

  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;

    if (!await File(modelPath).exists()) {
      throw Exception('LLM model not found at $modelPath');
    }

    _logger?.info('[LLMService] Initializing llama.cpp engine with config: $config');

    final contextParams = ContextParams()
      ..nCtx = config.kvCacheMaxSize
      ..nBatch = config.batchSize
      ..nPredict = config.maxOutputTokens
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

  /// Explicitly clears the active native KV cache slot.
  Future<void> clearKvCache({String reason = 'manual'}) async {
    if (_currentScope != null && _llama != null) {
      try {
        _logger?.info('[LLMService] Purging KV cache slot (reason: $reason)...');
        await _llama!.disposeScope(_currentScope!);
        _logger?.info('[LLMService] KV cache slot freed successfully. Native RAM reclaimed.');
      } catch (e) {
        _logger?.warning('[LLMService] Warning during KV cache scope disposal: $e');
      } finally {
        _currentScope = null;
      }
    }
  }

  void dispose() {
    _logger?.info('[LLMService] Disposing LLMService...');
    _currentScope = null;
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

