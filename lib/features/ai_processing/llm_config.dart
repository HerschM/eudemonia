import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Configuration for on-device LLM inference.
@immutable
class LLMConfig {
  /// Maximum token capacity for the Key-Value (KV) cache / context window.
  /// Maps directly to `ContextParams.nCtx`; selectable per load. Default is 4096 tokens.
  final int kvCacheMaxSize;

  /// Quantization type for Key and Value cache tensors.
  /// Options include `f16`, `q8_0`, `q4_0`. Using `q8_0` or `q4_0` drastically
  /// reduces KV cache RAM usage while preserving high context length.
  final LlamaKvCacheType kvCacheType;

  /// Idle time after which `ModelLifecycleManager` unloads the speech model from RAM.
  /// The language model is not governed by this value: a synthesis run unloads it when the
  /// run ends. Default is 3 minutes.
  final Duration modelInactivityTtl;

  /// Minimum batch size for prompt evaluation. `LLMService` raises `ContextParams.nBatch`
  /// to at least `kvCacheMaxSize`, because the binding rejects prompts longer than nBatch.
  final int batchSize;

  /// Number of CPU threads used for prompt evaluation and generation.
  /// Maps to `ContextParams.nThreads`. Default is 4 threads.
  final int threads;

  /// Whether sampling is greedy (always picks the most likely token).
  /// Maps to `SamplerParams.greedy`. Default is `true`: replies are structured text, so deterministic output is preferred; measured speed is the same as sampled.
  final bool greedySampling;

  /// Maximum time to wait for a single completion before generation is stopped
  /// and the call fails with a `TimeoutException` (partial text is discarded).
  /// Default is 8 minutes: a 4B model needed up to 6.8 minutes for a 700-word session on the
  /// Pixel 7a. Must stay below the synthesis wake-lock window.
  final Duration generationTimeout;

  /// Longest time to wait for the model to finish loading. A slow first load can exceed the
  /// llama_cpp_dart library's internal 60-second limit, after which the load is still
  /// running; `LLMService` keeps waiting up to this duration. Default is 180 seconds.
  final Duration modelLoadTimeout;

  const LLMConfig({
    this.kvCacheMaxSize = 4096,
    this.kvCacheType = LlamaKvCacheType.f16,
    this.modelInactivityTtl = const Duration(minutes: 3),
    this.batchSize = 512,
    this.threads = 4,
    this.greedySampling = true,
    this.generationTimeout = const Duration(minutes: 8),
    this.modelLoadTimeout = const Duration(seconds: 180),
  })  : assert(kvCacheMaxSize > 0, 'kvCacheMaxSize must be positive'),
        assert(threads > 0, 'threads must be positive');

  LLMConfig copyWith({
    int? kvCacheMaxSize,
    LlamaKvCacheType? kvCacheType,
    Duration? modelInactivityTtl,
    int? batchSize,
    int? threads,
    bool? greedySampling,
    Duration? generationTimeout,
    Duration? modelLoadTimeout,
  }) {
    return LLMConfig(
      kvCacheMaxSize: kvCacheMaxSize ?? this.kvCacheMaxSize,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      modelInactivityTtl: modelInactivityTtl ?? this.modelInactivityTtl,
      batchSize: batchSize ?? this.batchSize,
      threads: threads ?? this.threads,
      greedySampling: greedySampling ?? this.greedySampling,
      generationTimeout: generationTimeout ?? this.generationTimeout,
      modelLoadTimeout: modelLoadTimeout ?? this.modelLoadTimeout,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMConfig &&
          runtimeType == other.runtimeType &&
          kvCacheMaxSize == other.kvCacheMaxSize &&
          kvCacheType == other.kvCacheType &&
          modelInactivityTtl == other.modelInactivityTtl &&
          batchSize == other.batchSize &&
          threads == other.threads &&
          greedySampling == other.greedySampling &&
          generationTimeout == other.generationTimeout &&
          modelLoadTimeout == other.modelLoadTimeout;

  @override
  int get hashCode =>
      kvCacheMaxSize.hashCode ^
      kvCacheType.hashCode ^
      modelInactivityTtl.hashCode ^
      batchSize.hashCode ^
      threads.hashCode ^
      greedySampling.hashCode ^
      generationTimeout.hashCode ^
      modelLoadTimeout.hashCode;

  @override
  String toString() {
    return 'LLMConfig(kvCacheMaxSize: $kvCacheMaxSize, '
        'kvCacheType: ${kvCacheType.name}, '
        'modelInactivityTtl: ${modelInactivityTtl.inMinutes}m, batchSize: $batchSize, threads: $threads, greedySampling: $greedySampling, generationTimeout: ${generationTimeout.inSeconds}s)';
  }
}

/// Riverpod Notifier for managing runtime LLMConfig
class LLMConfigNotifier extends Notifier<LLMConfig> {
  @override
  LLMConfig build() => const LLMConfig();

  void updateConfig(LLMConfig config) {
    state = config;
  }
}

final llmConfigProvider = NotifierProvider<LLMConfigNotifier, LLMConfig>(() {
  return LLMConfigNotifier();
});
