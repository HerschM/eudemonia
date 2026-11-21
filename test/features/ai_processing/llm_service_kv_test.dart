import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';

void main() {
  group('LLMService KV Cache Policy', () {
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
