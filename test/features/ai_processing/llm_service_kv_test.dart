import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';

void main() {
  group('LLMService config plumbing', () {
    test('custom LLMConfig is retained by the service', () async {
      const customConfig = LLMConfig(kvCacheMaxSize: 8192, threads: 2);
      final service = LLMService(config: customConfig);
      expect(service.config.kvCacheMaxSize, equals(8192));
      expect(service.config.threads, equals(2));
      await service.dispose();
    });

    test('initialize fails clearly for a missing model file', () async {
      final service = LLMService(config: const LLMConfig(kvCacheMaxSize: 4096));
      await expectLater(
        service.initialize('/nonexistent/model.gguf'),
        throwsA(isA<Exception>()),
      );
      expect(service.isInitialized, isFalse);
      await service.dispose();
    });
  });
}
