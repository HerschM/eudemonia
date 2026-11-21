import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/text_eval.dart';

void main() {
  group('normalizeForComparison', () {
    test('lowercases, strips punctuation and collapses whitespace', () {
      expect(normalizeForComparison("  Hello,   World! It's 9:30. "),
          'hello world its 930');
    });
  });

  group('wordErrorRate', () {
    test('is 0 for identical text ignoring case and punctuation', () {
      expect(wordErrorRate('Buy milk.', 'buy MILK'), 0);
    });

    test('counts substitutions, insertions and deletions', () {
      expect(wordErrorRate('a b c d', 'a x c d'), 0.25); // substitution
      expect(wordErrorRate('a b c d', 'a b c d e'), 0.25); // insertion
      expect(wordErrorRate('a b c d', 'a b d'), 0.25); // deletion
      expect(wordErrorRate('a b', 'x y z'), 1.5);
    });

    test('handles empty strings', () {
      expect(wordErrorRate('', ''), 0);
      expect(wordErrorRate('a b', ''), 1);
    });
  });

  group('contentRecall', () {
    test('ignores filler words', () {
      expect(
          contentRecall('um I need to uh call you know the dentist',
              'I need to call the dentist'),
          1.0);
    });

    test('drops when a sentence is removed', () {
      final recall = contentRecall(
          'Buy milk today. Call the dentist tomorrow.', 'Buy milk today.');
      expect(recall, lessThan(0.7));
      expect(recall, greaterThan(0));
    });

    test('is 1 for a source with only fillers', () {
      expect(contentRecall('um uh', ''), 1.0);
    });
  });

  group('countFillers', () {
    test('counts listed fillers and phrases', () {
      expect(countFillers('Um, so I was, uh, thinking, you know, basically yeah'),
          4);
      expect(countFillers('so yeah umm ok'), 2);
    });

    test('does not count like or fillers inside words', () {
      expect(countFillers('I like the umbrella and the error'), 0);
    });
  });

  group('missingFacts', () {
    test('any acceptable spelling satisfies a fact', () {
      final facts = [
        ['nine thirty', '9:30', '9 30'],
        ['dentist'],
      ];
      expect(missingFacts('Call the dentist at 9:30.', facts), isEmpty);
      expect(missingFacts('Call the dentist at nine thirty', facts), isEmpty);
    });

    test('reports facts with no spelling present', () {
      final facts = [
        ['nine thirty', '9:30'],
        ['dentist'],
      ];
      expect(missingFacts('Call the doctor at 9:30', facts), ['dentist']);
    });

    test('matches whole words only', () {
      expect(missingFacts('the dentists', [['dentist']]), ['dentist']);
    });

    test('currency and thousands separators normalize', () {
      expect(
          missingFacts('about \$42,000 total', [
            ['forty two thousand', '42,000', '42000', '\$42,000']
          ]),
          isEmpty);
    });
  });

  group('manifest.json', () {
    final file = File('integration_test/voice_samples/manifest.json');
    late List<Map<String, dynamic>> entries;

    setUpAll(() {
      entries = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
    });

    test('every entry has the required keys and types', () {
      const keys = [
        'id',
        'file',
        'reference',
        'expectSpeech',
        'tags',
        'mustKeep',
        'expectedFolder'
      ];
      for (final e in entries) {
        for (final k in keys) {
          expect(e.containsKey(k), isTrue, reason: '${e['id']} missing $k');
        }
        expect(e['expectSpeech'], isA<bool>());
        expect(e['tags'], isA<List>());
        expect(e['mustKeep'], isA<List>());
        for (final fact in e['mustKeep'] as List) {
          expect(fact, isA<List>());
          expect((fact as List).isNotEmpty, isTrue);
        }
      }
    });

    test('ids are unique', () {
      final ids = entries.map((e) => e['id']).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every synthetic entry file exists on disk', () {
      final synthetic =
          entries.where((e) => (e['file'] as String).startsWith('synthetic/'));
      expect(synthetic, isNotEmpty);
      for (final e in synthetic) {
        expect(File('integration_test/voice_samples/${e['file']}').existsSync(),
            isTrue,
            reason: '${e['file']} missing');
      }
    });

    test('every scripted entry has a non-empty reference', () {
      // Free-form (10, 13, 22) and silence (20) real entries carry no reference.
      const unscripted = {'r10', 'r13', 'r22', 'r20', 's20'};
      for (final e in entries.where((e) => !unscripted.contains(e['id']))) {
        expect((e['reference'] as String?)?.trim().isNotEmpty, isTrue,
            reason: '${e['id']} needs a reference');
      }
      for (final id in unscripted) {
        expect(entries.firstWhere((e) => e['id'] == id)['reference'], isNull);
      }
    });

    test('only the silence entries expect no speech', () {
      final silent =
          entries.where((e) => e['expectSpeech'] == false).map((e) => e['id']);
      expect(silent.toSet(), {'r20', 's20'});
    });
  });
}
