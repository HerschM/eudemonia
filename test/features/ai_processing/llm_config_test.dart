import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:eudemonia/features/ai_processing/llm_config.dart';

void main() {
  group('LLMConfig', () {
    test('default configuration has expected values', () {
      const config = LLMConfig();
      expect(config.kvCacheMaxSize, equals(2048));
      expect(config.inputTokenLimit, equals(1536));
      expect(config.maxOutputTokens, equals(256));
      expect(config.kvCacheType, equals(LlamaKvCacheType.f16));
      expect(config.clearKvCacheEveryXTurns, equals(1));
      expect(config.kvCacheTtl, equals(const Duration(minutes: 2)));
      expect(config.modelInactivityTtl, equals(const Duration(minutes: 3)));
      expect(config.batchSize, equals(512));
      expect(config.threads, equals(4));
    });

    test('copyWith updates individual fields while preserving others', () {
      const base = LLMConfig();
      final updated = base.copyWith(
        kvCacheMaxSize: 1024,
        inputTokenLimit: 800,
        clearKvCacheEveryXTurns: 5,
        kvCacheType: LlamaKvCacheType.q8_0,
        modelInactivityTtl: const Duration(minutes: 10),
      );

      expect(updated.kvCacheMaxSize, equals(1024));
      expect(updated.inputTokenLimit, equals(800));
      expect(updated.clearKvCacheEveryXTurns, equals(5));
      expect(updated.kvCacheType, equals(LlamaKvCacheType.q8_0));
      expect(updated.modelInactivityTtl, equals(const Duration(minutes: 10)));
      expect(updated.maxOutputTokens, equals(256)); // Preserved
      expect(updated.threads, equals(4)); // Preserved
    });

    test('asserts inputTokenLimit must be smaller than kvCacheMaxSize', () {
      expect(
        () => LLMConfig(kvCacheMaxSize: 512, inputTokenLimit: 512),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => LLMConfig(kvCacheMaxSize: 512, inputTokenLimit: 1024),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equality and hashCode work properly', () {
      const config1 = LLMConfig(kvCacheMaxSize: 1024, inputTokenLimit: 512);
      const config2 = LLMConfig(kvCacheMaxSize: 1024, inputTokenLimit: 512);
      const config3 = LLMConfig(kvCacheMaxSize: 2048, inputTokenLimit: 1536);

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });

    test('toString contains all major parameters', () {
      const config = LLMConfig();
      final str = config.toString();
      expect(str, contains('kvCacheMaxSize: 2048'));
      expect(str, contains('clearKvCacheEveryXTurns: 1'));
      expect(str, contains('modelInactivityTtl: 3m'));
    });
  });
}
