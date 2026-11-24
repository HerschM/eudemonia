import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuration for on-device LLM inference.
@immutable
class LLMConfig {
  /// Maximum token capacity for the Key-Value (KV) cache / context window: prompt and output
  /// together. Maps to `llama_context_params.n_ctx`; selectable per load. Default is 4096 tokens.
  final int kvCacheMaxSize;

  /// Idle time after which `ModelLifecycleManager` unloads the speech model from RAM.
  /// The language model is not governed by this value: a synthesis run unloads it when the
  /// run ends. Default is 3 minutes.
  final Duration modelInactivityTtl;

  /// Maximum time to wait for a single completion before generation is stopped
  /// and the call fails with a `TimeoutException` (partial text is discarded).
  /// Default is 8 minutes: a 4B model needed up to 6.8 minutes for a 700-word session on the
  /// Pixel 7a. Must stay below the synthesis wake-lock window.
  final Duration generationTimeout;

  /// Longest time to wait for the model to finish loading (one native call on the worker);
  /// after it the worker is killed. Default is 180 seconds.
  final Duration modelLoadTimeout;

  /// Prompt tokens decoded per native call (`n_batch` = `n_ubatch`). A stop waits for at most
  /// one chunk, and only whole chunks of a shared prompt start are reused. Default is 64.
  final int promptChunkTokens;

  /// Whether a prompt reuses the memory of the whole chunks it shares with the previous prompt
  /// (IMPLEMENTATION.md 4.D). The reply is the same either way. Default is `true`.
  final bool reusePromptPrefix;

  const LLMConfig({
    this.kvCacheMaxSize = 4096,
    this.modelInactivityTtl = const Duration(minutes: 3),
    this.generationTimeout = const Duration(minutes: 8),
    this.modelLoadTimeout = const Duration(seconds: 180),
    this.promptChunkTokens = 64,
    this.reusePromptPrefix = true,
  })  : assert(kvCacheMaxSize > 0, 'kvCacheMaxSize must be positive'),
        assert(promptChunkTokens > 0, 'promptChunkTokens must be positive');

  LLMConfig copyWith({
    int? kvCacheMaxSize,
    Duration? modelInactivityTtl,
    Duration? generationTimeout,
    Duration? modelLoadTimeout,
    int? promptChunkTokens,
    bool? reusePromptPrefix,
  }) {
    return LLMConfig(
      kvCacheMaxSize: kvCacheMaxSize ?? this.kvCacheMaxSize,
      modelInactivityTtl: modelInactivityTtl ?? this.modelInactivityTtl,
      generationTimeout: generationTimeout ?? this.generationTimeout,
      modelLoadTimeout: modelLoadTimeout ?? this.modelLoadTimeout,
      promptChunkTokens: promptChunkTokens ?? this.promptChunkTokens,
      reusePromptPrefix: reusePromptPrefix ?? this.reusePromptPrefix,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LLMConfig &&
          runtimeType == other.runtimeType &&
          kvCacheMaxSize == other.kvCacheMaxSize &&
          modelInactivityTtl == other.modelInactivityTtl &&
          generationTimeout == other.generationTimeout &&
          modelLoadTimeout == other.modelLoadTimeout &&
          promptChunkTokens == other.promptChunkTokens &&
          reusePromptPrefix == other.reusePromptPrefix;

  @override
  int get hashCode => Object.hash(
      kvCacheMaxSize, modelInactivityTtl, generationTimeout, modelLoadTimeout, promptChunkTokens, reusePromptPrefix);

  @override
  String toString() {
    return 'LLMConfig(kvCacheMaxSize: $kvCacheMaxSize, '
        'modelInactivityTtl: ${modelInactivityTtl.inMinutes}m, generationTimeout: ${generationTimeout.inSeconds}s, '
        'promptChunkTokens: $promptChunkTokens, reusePromptPrefix: $reusePromptPrefix)';
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
