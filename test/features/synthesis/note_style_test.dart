import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ground rules every style's prompt keeps from the organised prompt.
const _sharedRules = [
  'The thoughts were dictated by one person, in order, and transcribed by speech recognition.',
  'a title of at most six words',
  'Keep what has already happened, what is planned and what is only wished as the speaker said it',
  'When the speaker corrects themselves, keep only the corrected version.',
  'Add nothing that was not said.',
  'Output only the note.',
  'Example:\nThoughts:\n1. Remind me to email Daniel the contract before Friday.\n',
];

String? problem(String id, String note) => noteStyleById(id).formProblem(note);

void main() {
  group('the style table', () {
    test('has the seven styles in picker order with their labels, organised first and the default', () {
      expect(noteStyles.map((s) => s.id),
          ['organised', 'concise', 'bullets', 'professional', 'journal', 'actionable', 'casual']);
      expect({for (final s in noteStyles) s.id: s.label}, {
        'organised': 'Organised',
        'concise': 'Short summary',
        'bullets': 'Key points',
        'professional': 'Professional',
        'journal': 'Journal entry',
        'actionable': 'Actionable next steps',
        'casual': 'Casual note',
      });
      expect(defaultNoteStyleId, 'organised');
      for (final s in noteStyles) {
        expect(s.description, isNotEmpty, reason: s.id);
        expect(s.description, isNot(contains('\n')), reason: 'one line: ${s.id}');
      }
    });

    test('unknown ids read as organised', () {
      expect(noteStyleById('no-such-style').id, 'organised');
      expect(isKnownNoteStyle('journal'), isTrue);
      expect(isKnownNoteStyle('no-such-style'), isFalse);
    });

    test('a note edited by hand has its own id and label but is not a style that can be chosen', () {
      expect(manualStyleId, 'manual');
      expect(manualStyleLabel, 'Edited by hand');
      expect(noteStyles.map((s) => s.id), isNot(contains(manualStyleId)));
      expect(isKnownNoteStyle(manualStyleId), isFalse);
      expect(noteStyleLabel(manualStyleId), 'Edited by hand');
      expect(noteStyleLabel('journal'), 'Journal entry');
      expect(noteStyleLabel('no-such-style'), 'Organised');
    });

    test('every prompt keeps the shared ground rules and ends with its own worked example', () {
      for (final s in noteStyles) {
        for (final rule in _sharedRules) {
          expect(s.systemPrompt, contains(rule), reason: '${s.id}: $rule');
        }
        expect(s.systemPrompt, contains('\nNote:\n**Contract and Park Street Flat**\n'), reason: s.id);
        expect(s.formProblem(s.systemPrompt.split('\nNote:\n').last), isNull,
            reason: 'the example of ${s.id} meets its own form');
      }
      // Each example is its own.
      expect(noteStyles.map((s) => s.systemPrompt.split('\nNote:\n').last).toSet(), hasLength(7));
    });

    test('the organised prompt is the tuned structured prompt, unchanged', () {
      final organised = noteStyleById('organised');
      expect(organised.systemPrompt, startsWith('You turn spoken thoughts into one organised written note.'));
      expect(organised.systemPrompt, contains('Every numbered thought must appear in the note.'));
      expect(organised.systemPrompt, endsWith('- I am a bit worried about the noise from the main road.'));
      expect(buildStructuredWritePrompt(['One.']), contains(organised.systemPrompt));
      expect(organised.minOutputRatio, isNull);
      expect(organised.maxOutputRatio, isNull);
      expect(organised.requiresEveryThought, isTrue);
      expect(organised.formProblem('anything at all'), isNull);
    });

    test('the user turn ends with the style\'s request; organised keeps "Write the note."', () {
      expect(noteStyleById('organised').request, 'Write the note.');
      expect(buildStructuredWritePrompt(['One.']), contains('Thoughts:\n1. One.\n\nWrite the note.<|im_end|>'));
      for (final s in noteStyles) {
        expect(buildStyleWritePrompt(['One.', 'Two.'], s), contains('Thoughts:\n1. One.\n2. Two.\n\n${s.request}<|im_end|>'),
            reason: s.id);
      }
      expect(noteStyleById('concise').request, contains('at most three short sentences'));
    });

    test('the actionable prompt asks for task lines and names the no-steps sentence', () {
      final p = noteStyleById('actionable').systemPrompt;
      expect(p, contains('"- [ ] "'));
      expect(p, contains(noNextStepsSentence));
      expect(p, contains('- [ ] Email Daniel the contract before Friday.'));
    });

    test('fact-keeping styles keep the profile ratios and the every-thought check; summary and steps do not', () {
      for (final id in ['organised', 'bullets', 'professional', 'journal', 'casual']) {
        final s = noteStyleById(id);
        expect(s.requiresEveryThought, isTrue, reason: id);
        expect(s.minOutputRatio, isNull, reason: id);
        expect(s.maxOutputRatio, isNull, reason: id);
        expect(s.splittable, isTrue, reason: id);
      }
      for (final id in ['concise', 'actionable']) {
        expect(noteStyleById(id).requiresEveryThought, isFalse, reason: id);
        expect(noteStyleById(id).minOutputRatio, 0, reason: id);
      }
      expect(noteStyleById('concise').maxOutputRatio, lessThan(1));
      expect(noteStyleById('concise').splittable, isFalse);
      expect(noteStyleById('actionable').splittable, isTrue);
    });
  });

  group('reply form rules', () {
    test('actionable: task lines or the exact no-steps sentence; no plain bullets, no other text', () {
      expect(problem('actionable', '**Plan**\n\n- [ ] Call Ana on Monday.\n- [ ] Buy 2 tickets.'), isNull);
      expect(problem('actionable', '**Plan**\n\n* [ ] Call Ana.\n- [x] Buy 2 tickets.'), isNull);
      expect(problem('actionable', '**Plan**\n\n**Work**\n- [ ] Call Ana.'), isNull, reason: 'headings may group steps');
      expect(problem('actionable', '**Thoughts**\n\n$noNextStepsSentence'), isNull);

      expect(problem('actionable', '**Plan**\n\n- Call Ana.\n- Buy tickets.'), isNotNull, reason: 'plain bullets');
      expect(problem('actionable', '**Plan**\n\n- [ ] Call Ana.\n- Buy tickets.'), isNotNull, reason: 'a plain bullet');
      expect(problem('actionable', '**Plan**\n\nI should call Ana.'), isNotNull, reason: 'no tasks');
      expect(problem('actionable', '**Plan**\n\n1. Call Ana.'), isNotNull, reason: 'numbered, not tasks');
      expect(problem('actionable', '**Plan**\n\n- [ ] Call Ana.\nI liked the flat a lot.'), isNotNull,
          reason: 'content that is not a step');
      expect(problem('actionable', '**Plan**\n\nNo next steps.'), isNotNull, reason: 'not the exact sentence');
      expect(problem('actionable', '**Plan**\n\n- [ ] Call Ana.\n$noNextStepsSentence'), isNotNull);
      expect(problem('actionable', ''), isNotNull);
    });

    test('journal and casual: no bullet or task lines', () {
      for (final id in ['journal', 'casual']) {
        expect(problem(id, '**Day**\n\nI went to the market. I felt calm.\n\nLater I called Mum.'), isNull, reason: id);
        expect(problem(id, '**Day**\n\n- I went to the market.'), isNotNull, reason: id);
        expect(problem(id, '**Day**\n\nI went out.\n* I called Mum.'), isNotNull, reason: id);
        expect(problem(id, '**Day**\n\n- [ ] Call Mum.'), isNotNull, reason: id);
        expect(problem(id, '**Day**\n\n• I went out.'), isNotNull, reason: id);
      }
    });

    test('bullets: at least one bullet and no heading after the title', () {
      expect(problem('bullets', '**Day**\n\n- I went to the market.\n- I called Mum.'), isNull);
      expect(problem('bullets', '**Day**\n\nI went to the market.'), isNotNull, reason: 'no bullet');
      expect(problem('bullets', '**Day**\n\n**Errands**\n- I went to the market.'), isNotNull, reason: 'a heading');
      expect(problem('bullets', '**Day**\n\n## Errands\n- I went to the market.'), isNotNull, reason: 'a heading');
      expect(problem('bullets', '**Day**\n\n- [ ] Call Mum.'), isNotNull, reason: 'tasks are not key points');
    });

    test('concise: no bullets or headings, one to three sentences', () {
      expect(problem('concise', '**Flat**\n\nI liked the flat. We decide by the 10th.'), isNull);
      expect(problem('concise', '**Flat**\n\nI liked the flat, which costs 1.5 times our rent. We decide soon! Sam sees it Sunday?'),
          isNull, reason: 'a decimal is not a sentence end; ! and ? are');
      expect(problem('concise', '**Flat**\n\nOne. Two. Three. Four.'), isNotNull, reason: 'four sentences');
      expect(problem('concise', '**Flat**\n\n- I liked the flat.'), isNotNull, reason: 'a bullet');
      expect(problem('concise', '**Flat**\n\n**Details**\nI liked it.'), isNotNull, reason: 'a heading');
      expect(problem('concise', '**Flat**'), isNotNull, reason: 'only a title');
    });

    test('professional and organised have no form rule beyond the word and thought checks', () {
      expect(problem('professional', '**Plan**\n\n**Tasks**\n- I will send the contract.'), isNull);
    });
  });

  group('joining pieces of a long session', () {
    test('organised and professional keep each piece as it is, later titles read as headings', () {
      for (final id in ['organised', 'professional']) {
        expect(noteStyleById(id).join('**A**\n- one', '**B**\n- two'), '**A**\n- one\n\n**B**\n- two', reason: id);
      }
    });

    test('bullets, journal and casual keep only the first title', () {
      expect(noteStyleById('bullets').join('**A**\n\n- one', '**B**\n\n- two'), '**A**\n\n- one\n\n- two');
      expect(noteStyleById('journal').join('**A**\n\nI went.', '# B\n\nI came back.'), '**A**\n\nI went.\n\nI came back.');
      expect(noteStyleById('casual').join('**A**\n\nHi.', 'No title here.'), '**A**\n\nHi.\n\nNo title here.',
          reason: 'a piece without a title loses nothing');
    });

    test('actionable keeps one title and drops the no-steps sentence when another piece has steps', () {
      final steps = noteStyleById('actionable');
      expect(steps.join('**A**\n\n- [ ] Call Ana.', '**B**\n\n$noNextStepsSentence'), '**A**\n\n- [ ] Call Ana.');
      expect(steps.join('**A**\n\n$noNextStepsSentence', '**B**\n\n- [ ] Call Ana.'), '**A**\n\n- [ ] Call Ana.');
      expect(steps.join('**A**\n\n$noNextStepsSentence', '**B**\n\n$noNextStepsSentence'), '**A**\n\n$noNextStepsSentence');
      final joined = steps.join('**A**\n\n- [ ] Call Ana.', '**B**\n\n- [ ] Buy 2 tickets.');
      expect(joined, '**A**\n\n- [ ] Call Ana.\n\n- [ ] Buy 2 tickets.');
      expect(steps.formProblem(joined), isNull);
    });
  });

  group('appending to a note edited by hand', () {
    test('adds an Added later heading and the fragment without its title, also without a trailing newline', () {
      expect(appendAddedLater('**My plan**\n\nI wrote this myself.', '**New bits**\n\n- Move it to Monday.'),
          '**My plan**\n\nI wrote this myself.\n\n**Added later**\n\n- Move it to Monday.');
      expect(appendAddedLater('Just my words.\n\n\n', '**New**\n- One.\n- Two.'),
          'Just my words.\n\n**Added later**\n\n- One.\n- Two.');
    });

    test('a fragment without a title is appended whole', () {
      expect(appendAddedLater('Mine.', 'Move it to Monday.'), 'Mine.\n\n**Added later**\n\nMove it to Monday.');
    });

    test('when Added later is already the last heading the body goes under it, without a second heading', () {
      const note = '**My plan**\n\nMine.\n\n**Added later**\n\n- Move it to Monday.';
      expect(appendAddedLater(note, '**Team**\n\n- Tell the team.'), '$note\n\n- Tell the team.');
      expect('**Added later**'.allMatches(appendAddedLater(note, '- Tell the team.')).length, 1);
    });

    test('when another heading follows Added later a new Added later heading is added', () {
      const note = '**My plan**\n\n**Added later**\n\n- Move it.\n\n**Shopping**\n- Milk.';
      expect(appendAddedLater(note, '**T**\n\n- Tell the team.'), '$note\n\n**Added later**\n\n- Tell the team.');
    });

    test('a fragment that is only a title keeps it, so nothing said is lost', () {
      expect(appendAddedLater('Mine.', '**Call Ana**'), 'Mine.\n\n**Added later**\n\n**Call Ana**');
    });
  });
}
