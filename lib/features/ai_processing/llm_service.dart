import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'llm_config.dart';
import 'note_classifier.dart';

export 'llm_config.dart';
export 'note_classifier.dart';

/// Legacy alias for NoteClassificationResult for backwards compatibility.
typedef LLMResponse = NoteClassificationResult;

class LLMService {
  final LLMConfig config;
  final AppLogger? _logger;
  LlamaParent? _llama;
  bool _isInitialized = false;

  int _completedTurnsCount = 0;
  LlamaScope? _currentScope;
  Timer? _kvCacheTtlTimer;

  LLMService({this.config = const LLMConfig(), this._logger});

  bool get isInitialized => _isInitialized;
  int get completedTurnsCount => _completedTurnsCount;
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
      modelParams: ModelParams(),
      contextParams: contextParams,
      samplingParams: SamplerParams(),
    );

    _llama = LlamaParent(loadCommand);
    await _llama!.init();
    _isInitialized = true;
    _completedTurnsCount = 0;
    _logger?.info('[LLMService] Llama engine initialized successfully (context: ${config.kvCacheMaxSize}, type: ${config.kvCacheType.name}).');
  }

  /// Explicitly clears the active native KV cache slot.
  Future<void> clearKvCache({String reason = 'manual'}) async {
    _kvCacheTtlTimer?.cancel();
    _kvCacheTtlTimer = null;

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

  void _resetKvCacheTimer() {
    _kvCacheTtlTimer?.cancel();
    _kvCacheTtlTimer = Timer(config.kvCacheTtl, () async {
      _logger?.info('[LLMService] KV cache TTL expired (${config.kvCacheTtl.inSeconds}s idle). Auto-clearing KV slot.');
      await clearKvCache(reason: 'TTL expired');
    });
  }

  Future<NoteClassificationResult> processText(String rawText) async {
    if (!_isInitialized || _llama == null) {
      _logger?.info('[LLMService] LLM not initialized, falling back to heuristic classifier.');
      final result = NoteClassifier.fallbackClassify(rawText, reason: 'LLM not initialized');
      result.printDebugLog(_logger);
      return result;
    }

    _completedTurnsCount++;
    _kvCacheTtlTimer?.cancel();

    _logger?.info('[LLMService] === Starting Inference Turn #$_completedTurnsCount ===');
    _logger?.info('[LLMService] KV Cache Policy: max=${config.kvCacheMaxSize}, clearEveryXTurns=${config.clearKvCacheEveryXTurns}');

    // Guard against excessive input length
    String sanitizedText = rawText;
    if (sanitizedText.length > config.inputTokenLimit * 4) {
      _logger?.warning('[LLMService] Input exceeds character guardrail limit (${config.inputTokenLimit * 4}). Truncating.');
      sanitizedText = sanitizedText.substring(0, config.inputTokenLimit * 4);
    }

    final prompt = NoteClassifier.buildPrompt(sanitizedText);
    final buffer = StringBuffer();
    final streamSub = _llama!.stream.listen((response) {
      buffer.write(response);
    });

    String fullResponse = '';
    final stopwatch = Stopwatch()..start();

    try {
      // Allocate or reuse active scope slot
      _currentScope ??= _llama!.getScope();

      final promptId = await _llama!.sendPrompt(prompt, scope: _currentScope);
      await _llama!.completions
          .firstWhere((e) => e.promptId == promptId)
          .timeout(const Duration(seconds: 25));
      fullResponse = buffer.toString();
    } catch (e) {
      _logger?.error('[LLMService] LLM generation error or timeout', error: e);
      fullResponse = buffer.toString();
    } finally {
      stopwatch.stop();
      await streamSub.cancel();
    }

    _logger?.info('[LLMService] Turn #$_completedTurnsCount completed in ${stopwatch.elapsedMilliseconds}ms.');

    // Evaluate turn-based KV cache purge policy
    if (config.clearKvCacheEveryXTurns > 0 &&
        _completedTurnsCount % config.clearKvCacheEveryXTurns == 0) {
      _logger?.info('[LLMService] Turn count ($_completedTurnsCount) matched clearKvCacheEveryXTurns (${config.clearKvCacheEveryXTurns}). Freeing KV cache.');
      await clearKvCache(reason: 'turn threshold reached');
    } else {
      // Schedule KV cache TTL countdown for inactivity
      _resetKvCacheTimer();
    }

    final result = NoteClassifier.parseResponse(rawText, fullResponse);
    result.printDebugLog(_logger);
    return result;
  }

  void dispose() {
    _logger?.info('[LLMService] Disposing LLMService...');
    _kvCacheTtlTimer?.cancel();
    _kvCacheTtlTimer = null;
    _currentScope = null;
    _completedTurnsCount = 0;
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

