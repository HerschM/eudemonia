import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_config.dart';

void main() {
  group('LLMConfig', () {
    test('default configuration has expected values', () {
      const config = LLMConfig();
      expect(config.kvCacheMaxSize, equals(4096));
      expect(config.modelInactivityTtl, equals(const Duration(minutes: 3)));
      expect(config.promptChunkTokens, equals(64));
      expect(config.reusePromptPrefix, isTrue);
    });

    test('copyWith updates individual fields while preserving others', () {
      const base = LLMConfig();
      final updated = base.copyWith(
        kvCacheMaxSize: 1024,
        modelInactivityTtl: const Duration(minutes: 10),
      );

      expect(updated.kvCacheMaxSize, equals(1024));
      expect(updated.modelInactivityTtl, equals(const Duration(minutes: 10)));
      expect(updated.promptChunkTokens, equals(64)); // Preserved
      expect(updated.reusePromptPrefix, isTrue); // Preserved
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

    test('copyWith updates promptChunkTokens and reusePromptPrefix, preserving others', () {
      const base = LLMConfig();
      final changed = base.copyWith(promptChunkTokens: 128, reusePromptPrefix: false);
      expect(changed.promptChunkTokens, equals(128));
      expect(changed.reusePromptPrefix, isFalse);
      expect(changed.kvCacheMaxSize, equals(4096));
    });

    test('configs differing only in promptChunkTokens or reusePromptPrefix are not equal', () {
      const base = LLMConfig();
      expect(base, isNot(equals(base.copyWith(promptChunkTokens: 32))));
      expect(base, isNot(equals(base.copyWith(reusePromptPrefix: false))));
    });

    test('toString includes promptChunkTokens and reusePromptPrefix', () {
      final str = const LLMConfig().toString();
      expect(str, contains('promptChunkTokens: 64'));
      expect(str, contains('reusePromptPrefix: true'));
    });

    test('generationTimeout defaults to 8 minutes', () {
      expect(const LLMConfig().generationTimeout,
          equals(const Duration(minutes: 8)));
    });

    test('copyWith updates generationTimeout, preserving others', () {
      final updated = const LLMConfig()
          .copyWith(generationTimeout: const Duration(seconds: 240));
      expect(updated.generationTimeout, equals(const Duration(seconds: 240)));
      expect(updated.promptChunkTokens, equals(64));
    });

    test('configs differing only in generationTimeout are not equal', () {
      const base = LLMConfig();
      expect(base,
          isNot(equals(base.copyWith(generationTimeout: const Duration(seconds: 1)))));
    });

    test('toString includes generationTimeout in seconds', () {
      expect(const LLMConfig().toString(), contains('generationTimeout: 480s'));
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
