import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
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

    test('chatmlNoThink opens the answer with an empty think block', () {
      for (final prompt in [
        buildStructuredWritePrompt(['One.'], format: ChatFormat.chatmlNoThink),
        buildOrganisePrompt(['One.'], format: ChatFormat.chatmlNoThink),
      ]) {
        expect(prompt, endsWith('<|im_start|>assistant\n<think>\n\n</think>\n\n'));
      }
      expect(buildWritePrompt(['One.']), endsWith('<|im_start|>assistant\n'));
    });

    test('the current profile is Qwen3-4B with structured notes and thinking off', () {
      const p = SynthesisModelProfile.current;
      expect(p.modelFileName, 'qwen3-4b.gguf');
      expect(p.chatFormat, ChatFormat.chatmlNoThink);
      expect(p.noteStyle, NoteStyle.structured);
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

  group('buildOrganiseGrammar', () {
    test('exactly one numbered line per thought, each one of the folders, nothing after', () {
      expect(
        buildOrganiseGrammar(2, defaultFolders),
        'root ::= "1: " folder "\\n2: " folder\n'
        'folder ::= "Work" | "Personal" | "Journal" | "Uncategorized"\n',
      );
      expect(buildOrganiseGrammar(1, defaultFolders), startsWith('root ::= "1: " folder\n'));
    });

    test('folder names are escaped as GBNF string literals', () {
      const folders = [
        FolderDefinition(name: r'Say "hi" \ bye', description: ''),
        FolderDefinition(name: 'Two\nlines\tand\x01', description: ''),
        FolderDefinition(name: 'Café', description: ''),
      ];
      expect(
        buildOrganiseGrammar(1, folders),
        'root ::= "1: " folder\n'
        r'folder ::= "Say \"hi\" \\ bye" | "Two\nlines\tand\x01" | "Café"'
        '\n',
      );
    });

    test('a reply in the form the grammar allows is one parseOrganiseReply accepts', () {
      // One sentence of the grammar's language for 3 thoughts (the host test runs the real sampler).
      const reply = '1: Journal\n2: Work\n3: Uncategorized';
      expect(parseOrganiseReply(reply, 3, defaultFolders), ['Journal', 'Work', 'Uncategorized']);
    });

    test('rejects a turn without thoughts or folders', () {
      expect(() => buildOrganiseGrammar(0, defaultFolders), throwsArgumentError);
      expect(() => buildOrganiseGrammar(2, const []), throwsArgumentError);
    });
  });

  test('output budgets', () {
    expect(organiseOutputBudget(3), 32);
    expect(writeOutputBudget(100), 256);
    expect(writeOutputBudget(10), 112);
    expect(structuredOutputBudget(100), 226);
  });

  test('structured prompt shows a worked example and demands every thought', () {
    final prompt = buildStructuredWritePrompt(['One.', 'Two.']);
    expect(prompt, contains('Every numbered thought must appear in the note.'));
    expect(prompt, contains('Example:\nThoughts:\n1. Remind me to email Daniel'));
    expect(prompt, contains('- I am a bit worried about the noise from the main road.<|im_end|>'));
    expect(prompt, contains('Thoughts:\n1. One.\n2. Two.\n\nWrite the note.<|im_end|>'));
  });

  group('thought coverage', () {
    const shoes = 'I already purchased running shoes yesterday, and we will get one pair for her also.';

    test('a faithful sentence covers the thought whatever the word endings', () {
      expect(thoughtCoverage(shoes, '- I already purchased running shoes; we will get a pair for her.'),
          greaterThan(0.7));
      expect(thoughtsMissingFrom('- I already purchased running shoes; we will get a pair for her.', [shoes]), isEmpty);
    });

    test('a note about other thoughts leaves this one out', () {
      const note = '**Tasks**\n- I need to call the dentist tomorrow at 9:30.';
      expect(thoughtCoverage(shoes, note), lessThan(minThoughtCoverage));
      expect(thoughtsMissingFrom(note, ['Call the dentist tomorrow at nine thirty and book a cleaning.', shoes]), [2]);
    });

    test('thoughts with fewer than four distinctive words are not judged', () {
      expect(thoughtsMissingFrom('Something else entirely.', ['Okay.', 'Water the plants.']), isEmpty);
      expect(thoughtCoverage('', 'anything'), 1);
    });
  });
}
