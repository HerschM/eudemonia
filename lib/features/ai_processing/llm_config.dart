import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Configuration for on-device LLM inference and KV cache lifecycle.
@immutable
class LLMConfig {
  /// Maximum token capacity for the Key-Value (KV) cache / context window.
  /// Maps directly to `ContextParams.nCtx`. Default is 2048 tokens.
  final int kvCacheMaxSize;

  /// Guardrail limit on raw input prompt tokens before truncation.
  /// Ensures sufficient remaining headroom within `kvCacheMaxSize` for generation.
  final int inputTokenLimit;

  /// Maximum tokens to generate per completion.
  /// Maps to `ContextParams.nPredict`. Default is 256 tokens.
  final int maxOutputTokens;

  /// Quantization type for Key and Value cache tensors.
  /// Options include `f16`, `q8_0`, `q4_0`. Using `q8_0` or `q4_0` drastically
  /// reduces KV cache RAM usage while preserving high context length.
  final LlamaKvCacheType kvCacheType;

  /// Frequency (in turns/calls) after which the KV cache slot is completely emptied.
  /// - `1` (default): Pure stateless single-turn call. KV cache is cleared immediately
  ///   after each note classification so no leftover context consumes RAM.
  /// - `x > 1`: Retains cache for `x` turns to benchmark token generation latency differences.
  /// - `<= 0`: Disables turn-based purging (relies purely on TTL).
  final int clearKvCacheEveryXTurns;

  /// Inactivity Time-To-Live for the Key-Value cache slot.
  /// If no LLM calls occur for this duration, the KV cache slot is freed even if
  /// the base model weights remain loaded in RAM. Default is 2 minutes.
  final Duration kvCacheTtl;

  /// Full model eviction Time-To-Live.
  /// If the app remains idle for this duration, both LLM and STT models are completely
  /// unloaded from RAM, reclaiming ~1.6 GB of memory. Default is 3 minutes.
  final Duration modelInactivityTtl;

  /// Batch size for prompt evaluation tokens. Maps to `ContextParams.nBatch`.
  final int batchSize;

  /// Number of CPU threads used for prompt evaluation and generation.
  /// Maps to `ContextParams.nThreads`. Default is 4 threads.
  final int threads;

  const LLMConfig({
    this.kvCacheMaxSize = 2048,
    this.inputTokenLimit = 1536,
    this.maxOutputTokens = 256,
    this.kvCacheType = LlamaKvCacheType.f16,
    this.clearKvCacheEveryXTurns = 1,
    this.kvCacheTtl = const Duration(minutes: 2),
    this.modelInactivityTtl = const Duration(minutes: 3),
    this.batchSize = 512,
    this.threads = 4,
  })  : assert(kvCacheMaxSize > 0, 'kvCacheMaxSize must be positive'),
        assert(inputTokenLimit > 0, 'inputTokenLimit must be positive'),
        assert(inputTokenLimit < kvCacheMaxSize,
            'inputTokenLimit must be smaller than kvCacheMaxSize to leave headroom for output generation'),
        assert(maxOutputTokens > 0, 'maxOutputTokens must be positive'),
        assert(threads > 0, 'threads must be positive');

  LLMConfig copyWith({
    int? kvCacheMaxSize,
    int? inputTokenLimit,
    int? maxOutputTokens,
    LlamaKvCacheType? kvCacheType,
    int? clearKvCacheEveryXTurns,
    Duration? kvCacheTtl,
    Duration? modelInactivityTtl,
    int? batchSize,
    int? threads,
  }) {
    return LLMConfig(
      kvCacheMaxSize: kvCacheMaxSize ?? this.kvCacheMaxSize,
      inputTokenLimit: inputTokenLimit ?? this.inputTokenLimit,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      clearKvCacheEveryXTurns:
          clearKvCacheEveryXTurns ?? this.clearKvCacheEveryXTurns,
      kvCacheTtl: kvCacheTtl ?? this.kvCacheTtl,
      modelInactivityTtl: modelInactivityTtl ?? this.modelInactivityTtl,
      batchSize: batchSize ?? this.batchSize,
      threads: threads ?? this.threads,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMConfig &&
          runtimeType == other.runtimeType &&
          kvCacheMaxSize == other.kvCacheMaxSize &&
          inputTokenLimit == other.inputTokenLimit &&
          maxOutputTokens == other.maxOutputTokens &&
          kvCacheType == other.kvCacheType &&
          clearKvCacheEveryXTurns == other.clearKvCacheEveryXTurns &&
          kvCacheTtl == other.kvCacheTtl &&
          modelInactivityTtl == other.modelInactivityTtl &&
          batchSize == other.batchSize &&
          threads == other.threads;

  @override
  int get hashCode =>
      kvCacheMaxSize.hashCode ^
      inputTokenLimit.hashCode ^
      maxOutputTokens.hashCode ^
      kvCacheType.hashCode ^
      clearKvCacheEveryXTurns.hashCode ^
      kvCacheTtl.hashCode ^
      modelInactivityTtl.hashCode ^
      batchSize.hashCode ^
      threads.hashCode;

  @override
  String toString() {
    return 'LLMConfig(kvCacheMaxSize: $kvCacheMaxSize, inputTokenLimit: $inputTokenLimit, '
        'maxOutputTokens: $maxOutputTokens, kvCacheType: ${kvCacheType.name}, '
        'clearKvCacheEveryXTurns: $clearKvCacheEveryXTurns, kvCacheTtl: ${kvCacheTtl.inSeconds}s, '
        'modelInactivityTtl: ${modelInactivityTtl.inMinutes}m, batchSize: $batchSize, threads: $threads)';
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
