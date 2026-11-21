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

    test('generate before the model is loaded throws StateError', () async {
      await expectLater(
        llmService.generate('prompt', maxOutputTokens: 16),
        throwsA(isA<StateError>()),
      );
    });

    test('generate after dispose throws StateError', () async {
      llmService.dispose();
      await expectLater(
        llmService.generate('prompt', maxOutputTokens: 16),
        throwsA(isA<StateError>()),
      );
    });
  });
}
