import 'package:flutter_test/flutter_test.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:eudemonia/features/ai_processing/llm_config.dart';

void main() {
  group('LLMConfig', () {
    test('default configuration has expected values', () {
      const config = LLMConfig();
      expect(config.kvCacheMaxSize, equals(4096));
      expect(config.kvCacheType, equals(LlamaKvCacheType.f16));
      expect(config.modelInactivityTtl, equals(const Duration(minutes: 3)));
      expect(config.batchSize, equals(512));
      expect(config.threads, equals(4));
    });

    test('copyWith updates individual fields while preserving others', () {
      const base = LLMConfig();
      final updated = base.copyWith(
        kvCacheMaxSize: 1024,
        kvCacheType: LlamaKvCacheType.q8_0,
        modelInactivityTtl: const Duration(minutes: 10),
      );

      expect(updated.kvCacheMaxSize, equals(1024));
      expect(updated.kvCacheType, equals(LlamaKvCacheType.q8_0));
      expect(updated.modelInactivityTtl, equals(const Duration(minutes: 10)));
      expect(updated.threads, equals(4)); // Preserved
    });

    test('equality and hashCode work properly', () {
      const config1 = LLMConfig(kvCacheMaxSize: 1024);
      const config2 = LLMConfig(kvCacheMaxSize: 1024);
      const config3 = LLMConfig(kvCacheMaxSize: 2048);

      expect(config1, equals(config2));
      expect(config1.hashCode, equals(config2.hashCode));
      expect(config1, isNot(equals(config3)));
    });

    test('toString contains all major parameters', () {
      const config = LLMConfig();
      final str = config.toString();
      expect(str, contains('kvCacheMaxSize: 4096'));
      expect(str, contains('modelInactivityTtl: 3m'));
    });

    test('gpuLayers and greedySampling default to 99 and true', () {
      const config = LLMConfig();
      expect(config.gpuLayers, equals(99));
      expect(config.greedySampling, isTrue);
    });

    test('copyWith updates gpuLayers and greedySampling, preserving others', () {
      const base = LLMConfig();
      final gpu = base.copyWith(gpuLayers: 0);
      expect(gpu.gpuLayers, equals(0));
      expect(gpu.greedySampling, isTrue);
      expect(gpu.threads, equals(4));
      final sampled = base.copyWith(greedySampling: false);
      expect(sampled.greedySampling, isFalse);
      expect(sampled.gpuLayers, equals(99));
      expect(sampled.threads, equals(4));
    });

    test('configs differing only in gpuLayers or greedySampling are not equal', () {
      const base = LLMConfig();
      expect(base, isNot(equals(base.copyWith(gpuLayers: 0))));
      expect(base, isNot(equals(base.copyWith(greedySampling: false))));
    });

    test('negative gpuLayers throws AssertionError', () {
      expect(() => LLMConfig(gpuLayers: -1), throwsA(isA<AssertionError>()));
    });

    test('toString includes gpuLayers and greedySampling', () {
      final str = const LLMConfig().toString();
      expect(str, contains('gpuLayers: 99'));
      expect(str, contains('greedySampling: true'));
    });

    test('generationTimeout defaults to 5 minutes', () {
      expect(const LLMConfig().generationTimeout,
          equals(const Duration(minutes: 5)));
    });

    test('copyWith updates generationTimeout, preserving others', () {
      final updated = const LLMConfig()
          .copyWith(generationTimeout: const Duration(seconds: 240));
      expect(updated.generationTimeout, equals(const Duration(seconds: 240)));
      expect(updated.threads, equals(4));
      expect(updated.gpuLayers, equals(99));
    });

    test('configs differing only in generationTimeout are not equal', () {
      const base = LLMConfig();
      expect(base,
          isNot(equals(base.copyWith(generationTimeout: const Duration(seconds: 1)))));
    });

    test('toString includes generationTimeout in seconds', () {
      expect(const LLMConfig().toString(), contains('generationTimeout: 300s'));
    });

    test('modelLoadTimeout defaults to 180s and takes part in copyWith and equality', () {
      const base = LLMConfig();
      expect(base.modelLoadTimeout, equals(const Duration(seconds: 180)));

      final longer = base.copyWith(modelLoadTimeout: const Duration(seconds: 300));
      expect(longer.modelLoadTimeout, equals(const Duration(seconds: 300)));
      expect(longer.generationTimeout, equals(base.generationTimeout));
      expect(longer, isNot(equals(base)));
    });
  });
}
