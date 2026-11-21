import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';

void main() {
  group('LLMService', () {
    late LLMService llmService;

    setUp(() {
      llmService = LLMService();
    });

    tearDown(() {
      llmService.dispose();
    });

    test('initial state is uninitialized', () {
      expect(llmService.isInitialized, isFalse);
    });
  });
}
