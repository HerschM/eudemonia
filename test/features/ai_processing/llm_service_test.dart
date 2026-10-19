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

    test('processText falls back to heuristic classifier and returns valid folder when uninitialized', () async {
      final result = await llmService.processText('um remember to schedule a meeting with client about the project');

      expect(result.rawText, equals('um remember to schedule a meeting with client about the project'));
      expect(result.correctedText, isNotEmpty);
      expect(result.selectedFolder, isIn(['Work', 'Todos']));
      expect(result.usedFallback, isTrue);
      expect(result.folderScores, isNotEmpty);
    });

    test('processText returns Uncategorized when uninitialized and input has no keywords', () async {
      final result = await llmService.processText('bla bla 123');

      expect(result.selectedFolder, equals('Uncategorized'));
      expect(result.usedFallback, isTrue);
    });
  });
}
