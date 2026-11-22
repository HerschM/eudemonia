import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildOrganisePrompt', () {
    test('contains every folder name and description and numbered thoughts', () {
      final prompt = buildOrganisePrompt(['Buy milk.', 'Fix the login bug.']);
      for (final f in defaultFolders) {
        expect(prompt, contains('- ${f.name}: ${f.description}'));
      }
      expect(prompt, contains('Thoughts:\n1. Buy milk.\n2. Fix the login bug.\nAnswer:'));
      expect(prompt, startsWith('<|im_start|>system\n'));
      expect(prompt, endsWith('Answer:<|im_end|>\n<|im_start|>assistant\n'));
      expect(prompt, isNot(contains('Notes already in progress')));
    });

    test('includes open sessions when given', () {
      final prompt = buildOrganisePrompt(
        ['Also remove the second screen.'],
        openSessions: const [OpenSessionContext(folder: 'Work', note: 'Redesign onboarding.')],
      );
      expect(prompt, contains('Notes already in progress:\n[Work] Redesign onboarding.\n\nThoughts:'));
    });

    test('uses a custom folder list', () {
      final prompt = buildOrganisePrompt(['x'],
          folders: const [FolderDefinition(name: 'Gym', description: 'training.')]);
      expect(prompt, contains('- Gym: training.'));
      expect(prompt, isNot(contains('- Work:')));
    });
  });

  group('write prompts', () {
    test('write prompt numbers the thoughts', () {
      final prompt = buildWritePrompt(['One.', 'Two.']);
      expect(prompt, contains('Thoughts:\n1. One.\n2. Two.\n\nWrite the note.<|im_end|>'));
      expect(prompt, contains('All thoughts matter equally'));
    });
  });

  group('parseOrganiseReply', () {
    test('accepts a correct reply, tolerating whitespace', () {
      expect(parseOrganiseReply('1: Work\n2:Personal \n 3 : Journal\n', 3, defaultFolders),
          ['Work', 'Personal', 'Journal']);
    });

    test('rejects a missing line', () {
      expect(parseOrganiseReply('1: Work\n2: Personal', 3, defaultFolders), isNull);
    });

    test('rejects an extra line', () {
      expect(parseOrganiseReply('1: Work\n2: Personal', 1, defaultFolders), isNull);
    });

    test('rejects wrong numbering', () {
      expect(parseOrganiseReply('1: Work\n3: Personal', 2, defaultFolders), isNull);
    });

    test('rejects an unknown folder', () {
      expect(parseOrganiseReply('1: Work\n2: Ideas', 2, defaultFolders), isNull);
      expect(parseOrganiseReply('1: work', 1, defaultFolders), isNull);
    });

    test('rejects an empty reply and lines without a number', () {
      expect(parseOrganiseReply('  \n', 1, defaultFolders), isNull);
      expect(parseOrganiseReply('Work', 1, defaultFolders), isNull);
      expect(parseOrganiseReply(': Work', 1, defaultFolders), isNull);
    });

    test('accepts a dot or bracket after the number and blank lines between entries', () {
      expect(parseOrganiseReply('1. Journal\n\n2) Personal\n3 . Work', 3, defaultFolders),
          ['Journal', 'Personal', 'Work']);
    });

    test('ignores one heading line before the entries', () {
      expect(parseOrganiseReply('Thoughts:\n1. Journal\n2. Personal', 2, defaultFolders), ['Journal', 'Personal']);
      expect(parseOrganiseReply('Here are the sorted thoughts:\n\n1: Work', 1, defaultFolders), ['Work']);
    });

    test('rejects any other extra text', () {
      // Two heading lines, a heading with a digit, text after the entries, a comment on an entry.
      expect(parseOrganiseReply('Sure.\nThoughts:\n1: Work', 1, defaultFolders), isNull);
      expect(parseOrganiseReply('The 2 thoughts:\n1: Work\n2: Work', 2, defaultFolders), isNull);
      expect(parseOrganiseReply('1: Work\nAll thoughts are about work.', 1, defaultFolders), isNull);
      expect(parseOrganiseReply('1: Work (the app)', 1, defaultFolders), isNull);
      expect(parseOrganiseReply('Thoughts:', 1, defaultFolders), isNull);
    });

    test('a heading does not excuse a wrong number of entries', () {
      final eight = 'Here are the sorted thoughts:\n${[for (var i = 1; i <= 8; i++) '$i. Work'].join('\n')}';
      expect(parseOrganiseReply(eight, 5, defaultFolders), isNull);
      expect(parseOrganiseReply('Thoughts:\n1. Work', 2, defaultFolders), isNull);
    });
  });

  test('output budgets', () {
    expect(organiseOutputBudget(3), 32);
    expect(writeOutputBudget(100), 256);
    expect(writeOutputBudget(10), 112);
  });
}
