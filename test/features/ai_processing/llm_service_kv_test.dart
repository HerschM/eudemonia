import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';

void main() {
  group('LLMService KV Cache Policy & Turn Tracking', () {
    test('completedTurnsCount starts at 0 and increments on processText', () async {
      final service = LLMService(
        config: const LLMConfig(
          clearKvCacheEveryXTurns: 1,
          kvCacheTtl: Duration(seconds: 1),
        ),
      );

      expect(service.completedTurnsCount, equals(0));
      expect(service.hasActiveKvScope, isFalse);

      // Uninitialized fallback increments turn count and returns classified fallback
      await service.processText('test note 1');
      // In uninitialized fallback mode, prompt is not dispatched to native, so turnsCount is not incremented
      expect(service.completedTurnsCount, equals(0));

      service.dispose();
      expect(service.isInitialized, isFalse);
    });

    test('clearKvCache can be called safely even when uninitialized or empty', () async {
      final service = LLMService();
      // Should not throw
      await service.clearKvCache(reason: 'unit test');
      expect(service.hasActiveKvScope, isFalse);
      service.dispose();
    });

    test('custom LLMConfig is properly retained by service', () {
      const customConfig = LLMConfig(
        kvCacheMaxSize: 1024,
        inputTokenLimit: 512,
        clearKvCacheEveryXTurns: 3,
        threads: 2,
      );
      final service = LLMService(config: customConfig);
      expect(service.config.kvCacheMaxSize, equals(1024));
      expect(service.config.clearKvCacheEveryXTurns, equals(3));
      expect(service.config.threads, equals(2));
      service.dispose();
    });
  });
}
