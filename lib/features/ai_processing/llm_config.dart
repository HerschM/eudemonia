import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Configuration for on-device LLM inference.
@immutable
class LLMConfig {
  /// Maximum token capacity for the Key-Value (KV) cache / context window.
  /// Maps directly to `ContextParams.nCtx`; selectable per load. Default is 2048 tokens.
  final int kvCacheMaxSize;

  /// Default output budget for callers that have no per-call estimate. Not passed to the
  /// engine: `LLMService.generate` enforces its own per-call `maxOutputTokens`.
  final int maxOutputTokens;

  /// Quantization type for Key and Value cache tensors.
  /// Options include `f16`, `q8_0`, `q4_0`. Using `q8_0` or `q4_0` drastically
  /// reduces KV cache RAM usage while preserving high context length.
  final LlamaKvCacheType kvCacheType;

  /// Full model eviction Time-To-Live.
  /// If the app remains idle for this duration, both LLM and STT models are completely
  /// unloaded from RAM, reclaiming ~1.6 GB of memory. Default is 3 minutes.
  final Duration modelInactivityTtl;

  /// Minimum batch size for prompt evaluation. `LLMService` raises `ContextParams.nBatch`
  /// to at least `kvCacheMaxSize`, because the binding rejects prompts longer than nBatch.
  final int batchSize;

  /// Number of CPU threads used for prompt evaluation and generation.
  /// Maps to `ContextParams.nThreads`. Default is 4 threads.
  final int threads;

  /// Number of model layers offloaded to the GPU (Vulkan).
  /// Maps to `ModelParams.nGpuLayers`. `0` = CPU only. Default is 99 (full offload,
  /// the llama_cpp_dart library default).
  final int gpuLayers;

  /// Whether sampling is greedy (always picks the most likely token).
  /// Maps to `SamplerParams.greedy`. Default is `true`: replies are structured text, so deterministic output is preferred; measured speed is the same as sampled.
  final bool greedySampling;

  /// Maximum time to wait for a single completion before generation is stopped
  /// and the call fails with a `TimeoutException` (partial text is discarded).
  /// Default is 60 seconds.
  final Duration generationTimeout;

  /// Longest time to wait for the model to finish loading. The first load after an
  /// install is the slowest (GPU pipelines are compiled from scratch) and can exceed the
  /// llama_cpp_dart library's internal 60-second limit, after which the load is still
  /// running; `LLMService` keeps waiting up to this duration. Default is 180 seconds.
  final Duration modelLoadTimeout;

  const LLMConfig({
    this.kvCacheMaxSize = 2048,
    this.maxOutputTokens = 256,
    this.kvCacheType = LlamaKvCacheType.f16,
    this.modelInactivityTtl = const Duration(minutes: 3),
    this.batchSize = 512,
    this.threads = 4,
    this.gpuLayers = 99,
    this.greedySampling = true,
    this.generationTimeout = const Duration(seconds: 60),
    this.modelLoadTimeout = const Duration(seconds: 180),
  })  : assert(kvCacheMaxSize > 0, 'kvCacheMaxSize must be positive'),
        assert(maxOutputTokens > 0, 'maxOutputTokens must be positive'),
        assert(threads > 0, 'threads must be positive'),
        assert(gpuLayers >= 0, 'gpuLayers must be non-negative');

  LLMConfig copyWith({
    int? kvCacheMaxSize,
    int? maxOutputTokens,
    LlamaKvCacheType? kvCacheType,
    Duration? modelInactivityTtl,
    int? batchSize,
    int? threads,
    int? gpuLayers,
    bool? greedySampling,
    Duration? generationTimeout,
    Duration? modelLoadTimeout,
  }) {
    return LLMConfig(
      kvCacheMaxSize: kvCacheMaxSize ?? this.kvCacheMaxSize,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      modelInactivityTtl: modelInactivityTtl ?? this.modelInactivityTtl,
      batchSize: batchSize ?? this.batchSize,
      threads: threads ?? this.threads,
      gpuLayers: gpuLayers ?? this.gpuLayers,
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
          maxOutputTokens == other.maxOutputTokens &&
          kvCacheType == other.kvCacheType &&
          modelInactivityTtl == other.modelInactivityTtl &&
          batchSize == other.batchSize &&
          threads == other.threads &&
          gpuLayers == other.gpuLayers &&
          greedySampling == other.greedySampling &&
          generationTimeout == other.generationTimeout &&
          modelLoadTimeout == other.modelLoadTimeout;

  @override
  int get hashCode =>
      kvCacheMaxSize.hashCode ^
      maxOutputTokens.hashCode ^
      kvCacheType.hashCode ^
      modelInactivityTtl.hashCode ^
      batchSize.hashCode ^
      threads.hashCode ^
      gpuLayers.hashCode ^
      greedySampling.hashCode ^
      generationTimeout.hashCode ^
      modelLoadTimeout.hashCode;

  @override
  String toString() {
    return 'LLMConfig(kvCacheMaxSize: $kvCacheMaxSize, '
        'maxOutputTokens: $maxOutputTokens, kvCacheType: ${kvCacheType.name}, '
        'modelInactivityTtl: ${modelInactivityTtl.inMinutes}m, batchSize: $batchSize, threads: $threads, gpuLayers: $gpuLayers, greedySampling: $greedySampling, generationTimeout: ${generationTimeout.inSeconds}s)';
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
