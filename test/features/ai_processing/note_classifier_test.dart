import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/note_classifier.dart';

void main() {
  group('NoteClassifier - buildPrompt', () {
    test('creates ChatML formatted prompt containing all 4 folders', () {
      const rawText = 'um I have an idea for a new mobile app';
      final prompt = NoteClassifier.buildPrompt(rawText);

      expect(prompt, contains('<|im_start|>system'));
      expect(prompt, contains('<|im_end|>'));
      expect(prompt, contains('<|im_start|>user'));
      expect(prompt, contains('<|im_start|>assistant'));
      expect(prompt, contains(rawText));
      expect(prompt, contains('"Work"'));
      expect(prompt, contains('"Ideas"'));
      expect(prompt, contains('"Todos"'));
      expect(prompt, contains('"Journal"'));
    });
  });

  group('NoteClassifier - parseResponse', () {
    test('parses clean valid JSON response correctly', () {
      const rawText = 'need to finish the quarterly budget report for client';
      const llmJson = '''
{
  "corrected_text": "Need to finish the quarterly budget report for the client.",
  "confidence_scores": {
    "Work": 0.85,
    "Ideas": 0.05,
    "Todos": 0.05,
    "Journal": 0.05
  },
  "folder": "Work",
  "reasoning": "Professional client project deadline."
}
''';

      final result = NoteClassifier.parseResponse(rawText, llmJson);

      expect(result.rawText, equals(rawText));
      expect(result.correctedText, equals('Need to finish the quarterly budget report for the client.'));
      expect(result.selectedFolder, equals('Work'));
      expect(result.folder, equals('Work'));
      expect(result.folderScores['Work'], equals(0.85));
      expect(result.reasoning, equals('Professional client project deadline.'));
      expect(result.usedFallback, isFalse);
    });

    test('fixes user bug: disambiguates "Work/Ideas/Todos/Journal" to a single folder via confidence scores', () {
      const rawText = 'what if we built an AI voice assistant that categorizes thoughts';
      // The model reproduced the prompt template literally:
      const llmJsonWithLiteralExample = '''
{
  "corrected_text": "What if we built an AI voice assistant that categorizes thoughts?",
  "confidence_scores": {
    "Work": 0.10,
    "Ideas": 0.75,
    "Todos": 0.05,
    "Journal": 0.10
  },
  "folder": "Work/Ideas/Todos/Journal",
  "reasoning": "Brainstorming a new product feature."
}
''';

      final result = NoteClassifier.parseResponse(rawText, llmJsonWithLiteralExample);

      // Must NEVER be the composite slash string
      expect(result.selectedFolder, isNot(equals('Work/Ideas/Todos/Journal')));
      expect(result.selectedFolder, isNot(contains('/')));
      // Must pick Ideas because Ideas has highest confidence (0.75)
      expect(result.selectedFolder, equals('Ideas'));
      expect(result.folder, equals('Ideas'));
    });

    test('disambiguates composite folder without scores using keyword heuristics', () {
      const rawText = 'remember to call the doctor tomorrow morning to pick up my prescription';
      const llmJson = '''
{
  "corrected_text": "Remember to call the doctor tomorrow morning to pick up my prescription.",
  "folder": "Work/Ideas/Todos/Journal"
}
''';

      final result = NoteClassifier.parseResponse(rawText, llmJson);

      expect(result.selectedFolder, equals('Todos'));
      expect(result.folder, equals('Todos'));
    });

    test('strips markdown code blocks and handles leading/trailing text', () {
      const rawText = 'today was a really peaceful day and I felt very grateful';
      const markdownOutput = '''
Here is your formatted JSON:
```json
{
  "corrected_text": "Today was a really peaceful day and I felt very grateful.",
  "confidence_scores": {
    "Work": 0.0,
    "Ideas": 0.0,
    "Todos": 0.0,
    "Journal": 1.0
  },
  "folder": "Journal",
  "reasoning": "Personal gratitude reflection."
}
```
Hope this helps!
''';

      final result = NoteClassifier.parseResponse(rawText, markdownOutput);

      expect(result.selectedFolder, equals('Journal'));
      expect(result.correctedText, equals('Today was a really peaceful day and I felt very grateful.'));
      expect(result.usedFallback, isFalse);
    });

    test('normalizes folder casing and trims whitespace', () {
      const rawText = 'discuss sprint backlog with the team';
      const llmJson = '''
{
  "corrected_text": "Discuss sprint backlog with the team.",
  "folder": "  work  "
}
''';

      final result = NoteClassifier.parseResponse(rawText, llmJson);
      expect(result.selectedFolder, equals('Work'));
    });

    test('maps common category synonyms to standard folders', () {
      expect(NoteClassifier.parseResponse('text', '{"folder": "Personal"}').selectedFolder, equals('Journal'));
      expect(NoteClassifier.parseResponse('text', '{"folder": "Tasks"}').selectedFolder, equals('Todos'));
      expect(NoteClassifier.parseResponse('text', '{"folder": "Startup Idea"}').selectedFolder, equals('Ideas'));
      expect(NoteClassifier.parseResponse('text', '{"folder": "Office Meeting"}').selectedFolder, equals('Work'));
    });

    test('falls back gracefully on completely invalid JSON output', () {
      const rawText = 'um remember to buy some milk and eggs';
      const gibberishOutput = 'I am unable to output JSON at this moment.';

      final result = NoteClassifier.parseResponse(rawText, gibberishOutput);

      expect(result.usedFallback, isTrue);
      expect(result.selectedFolder, equals('Todos'));
      expect(result.correctedText, contains('Remember to buy some milk and eggs'));
    });
  });

  group('NoteClassifier - cleanRawText', () {
    test('removes conversational fillers and fixes punctuation & capitalization', () {
      const raw = 'um uh basically we need to schedule a meeting with the client';
      final cleaned = NoteClassifier.cleanRawText(raw);

      expect(cleaned, equals('We need to schedule a meeting with the client.'));
      expect(cleaned, isNot(contains('um')));
      expect(cleaned, isNot(contains('basically')));
    });

    test('preserves already well-formed text', () {
      const input = 'Call John tomorrow at noon.';
      expect(NoteClassifier.cleanRawText(input), equals('Call John tomorrow at noon.'));
    });
  });

  group('NoteClassifier - fallbackClassify', () {
    test('classifies Todos accurately via keywords', () {
      final res = NoteClassifier.fallbackClassify('need to buy groceries and schedule doctor appointment');
      expect(res.selectedFolder, equals('Todos'));
      expect(res.folderScores['Todos']!, greaterThan(0.5));
    });

    test('classifies Work accurately via keywords', () {
      final res = NoteClassifier.fallbackClassify('client presentation on quarterly revenue and sprint deadline');
      expect(res.selectedFolder, equals('Work'));
      expect(res.folderScores['Work']!, greaterThan(0.5));
    });

    test('classifies Ideas accurately via keywords', () {
      final res = NoteClassifier.fallbackClassify('what if we design a new concept app for inventors');
      expect(res.selectedFolder, equals('Ideas'));
      expect(res.folderScores['Ideas']!, greaterThan(0.5));
    });

    test('classifies Journal accurately via keywords', () {
      final res = NoteClassifier.fallbackClassify('today I felt grateful and reflection on my morning walk');
      expect(res.selectedFolder, equals('Journal'));
      expect(res.folderScores['Journal']!, greaterThan(0.5));
    });

    test('returns Uncategorized when text matches no domain keywords', () {
      final res = NoteClassifier.fallbackClassify('xyz 123 456');
      expect(res.selectedFolder, equals('Uncategorized'));
    });
  });

  group('NoteClassificationResult - formatting and debug logs', () {
    test('formattedScores produces clean percentage string', () {
      final res = NoteClassificationResult(
        rawText: 'test',
        correctedText: 'Test.',
        selectedFolder: 'Work',
        folderScores: {
          'Work': 0.70,
          'Ideas': 0.15,
          'Todos': 0.10,
          'Journal': 0.05,
        },
      );

      expect(res.formattedScores, equals('Work: 70% | Ideas: 15% | Todos: 10% | Journal: 5%'));
    });
  });
}
