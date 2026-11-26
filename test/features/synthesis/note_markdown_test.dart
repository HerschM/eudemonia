import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown_view.dart';

const _example = '''**Flat and Contract Updates**

**Daniel's contract**
- I signed the contract with Daniel on Monday.
- He will send the countersigned copy this week.

**Park Street flat**
- The viewing is on Thursday at five.''';

List<String> _words(String s) =>
    s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Input words with every asterisk, leading `#` run and leading bullet marker removed.
List<String> _inputWordsWithoutMarkers(String input) {
  final lines = input.split(RegExp(r'\r\n|\r|\n')).map((l) {
    var t = l.trim();
    t = t.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
    t = t.replaceFirst(RegExp(r'^[-*•]\s+'), '');
    return t.replaceAll('*', '');
  });
  return _words(lines.join(' '));
}

List<String> _blockWords(List<NoteBlock> blocks) =>
    _words(blocks.map((b) => b.text.replaceAll('*', '')).join(' '));

TextStyle? _styleOf(WidgetTester tester, String text) => tester
    .widget<Text>(find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == text))
    .textSpan
    ?.style;

void main() {
  group('parseNoteMarkdown', () {
    test('parses the model example into title, headings and bullets', () {
      final blocks = parseNoteMarkdown(_example);
      expect(blocks.map((b) => b.kind).toList(), [
        NoteBlockKind.title,
        NoteBlockKind.heading,
        NoteBlockKind.bullet,
        NoteBlockKind.bullet,
        NoteBlockKind.heading,
        NoteBlockKind.bullet,
      ]);
      expect(blocks[0].text, 'Flat and Contract Updates');
      expect(blocks[1].text, "Daniel's contract");
      expect(blocks[2].text, 'I signed the contract with Daniel on Monday.');
      expect(blocks[3].text, 'He will send the countersigned copy this week.');
      expect(blocks[4].text, 'Park Street flat');
      expect(blocks[5].text, 'The viewing is on Thursday at five.');
      expect(blocks.any((b) => b.text.contains('*')), isFalse);
    });

    test('hash headings: first is the title, later ones are headings', () {
      final blocks = parseNoteMarkdown('# Plan\n\n## Week one\n### Day two\nSome words.');
      expect(blocks.map((b) => b.kind).toList(), [
        NoteBlockKind.title,
        NoteBlockKind.heading,
        NoteBlockKind.heading,
        NoteBlockKind.paragraph,
      ]);
      expect(blocks.map((b) => b.text).toList(),
          ['Plan', 'Week one', 'Day two', 'Some words.']);
    });

    test('a bold heading may carry a trailing colon', () {
      final blocks = parseNoteMarkdown('**Groceries**:\n- milk');
      expect(blocks[0].kind, NoteBlockKind.title);
      expect(blocks[0].text, 'Groceries:');
    });

    test('a note with no markup is paragraphs only, lines joined with a space', () {
      final blocks = parseNoteMarkdown(
          'I need to call the plumber.\nThen buy bread.\n\nAlso book the dentist.');
      expect(blocks.map((b) => b.kind).toSet(), {NoteBlockKind.paragraph});
      expect(blocks.map((b) => b.text).toList(), [
        'I need to call the plumber. Then buy bread.',
        'Also book the dentist.',
      ]);
    });

    test('inline bold inside a bullet becomes a bold span', () {
      final blocks = parseNoteMarkdown('- Call **Daniel** before noon');
      expect(blocks.single.kind, NoteBlockKind.bullet);
      expect(blocks.single.spans, const [
        NoteSpan('Call '),
        NoteSpan('Daniel', bold: true),
        NoteSpan(' before noon'),
      ]);
    });

    test('all three bullet markers are recognised', () {
      final blocks = parseNoteMarkdown('- one\n* two\n• three');
      expect(blocks.map((b) => b.kind).toSet(), {NoteBlockKind.bullet});
      expect(blocks.map((b) => b.text).toList(), ['one', 'two', 'three']);
    });

    test('unmatched asterisks are kept as literal text', () {
      final blocks = parseNoteMarkdown('Price is 5 ** 2 and **open ended');
      expect(blocks.single.kind, NoteBlockKind.paragraph);
      expect(blocks.single.text, 'Price is 5 ** 2 and **open ended');
      expect(blocks.single.spans.any((s) => s.bold), isFalse);
    });

    test('wrapped bullet continuation joins the bullet', () {
      final blocks = parseNoteMarkdown(
          '- First part of a long bullet\n  continues here\ndirectly follows\n- Next');
      expect(blocks.length, 2);
      expect(blocks[0].kind, NoteBlockKind.bullet);
      expect(blocks[0].text,
          'First part of a long bullet continues here directly follows');
      expect(blocks[1].text, 'Next');
    });

    test('blank lines only separate blocks', () {
      final blocks = parseNoteMarkdown('\n\n- a\n\n\n- b\n\n');
      expect(blocks.map((b) => b.text).toList(), ['a', 'b']);
    });

    test('empty and whitespace input give no blocks', () {
      expect(parseNoteMarkdown(''), isEmpty);
      expect(parseNoteMarkdown('  \n \n'), isEmpty);
    });

    test('plainNotePreview strips markers into one run of words', () {
      expect(plainNotePreview('**Title**\n- one **two**\n- three'),
          'Title one two three');
    });

    test('never drops a word, for several inputs', () {
      final longNote = [
        '**Long note**',
        for (var p = 0; p < 6; p++) ...[
          '',
          '**Topic $p**',
          for (var b = 0; b < 5; b++)
            '- item $p-$b has ${List.generate(8, (i) => 'w${p}_${b}_$i').join(' ')} and **bold$p$b**',
        ],
        '',
        'Closing paragraph',
        'on two lines.',
      ].join('\n');
      expect(_words(longNote).length, greaterThanOrEqualTo(300));

      final inputs = [
        _example,
        longNote,
        'plain only',
        '**unclosed bold and * stray star\n- bullet with ** ** gap\n#nohash heading? # \n###\n- ',
        '# A\r\n- b\r\n  c\r\n\r\n* d **e** f',
        '**a** and **b**\n**only bold**:\n****\n**',
        '',
        '•\n-\n*\n#',
      ];
      for (final input in inputs) {
        final blocks = parseNoteMarkdown(input);
        expect(_blockWords(blocks), _inputWordsWithoutMarkers(input),
            reason: 'input: ${input.length > 60 ? input.substring(0, 60) : input}');
      }
    });
  });

  group('NoteMarkdownView', () {
    testWidgets('renders the example at 360dp with no asterisks, bold title and headings',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: NoteMarkdownView(text: _example),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('*'), findsNothing);
      expect(find.text('•'), findsNWidgets(3));

      FontWeight? weightOf(String text) {
        return _styleOf(tester, text)?.fontWeight;
      }

      double? sizeOf(String text) {
        return _styleOf(tester, text)?.fontSize;
      }

      expect(weightOf('Flat and Contract Updates'), FontWeight.w700);
      expect(weightOf("Daniel's contract"), FontWeight.w700);
      expect(weightOf('Park Street flat'), FontWeight.w700);
      expect(weightOf('I signed the contract with Daniel on Monday.'), isNot(FontWeight.w700));
      expect(sizeOf('Flat and Contract Updates')!,
          greaterThan(sizeOf("Daniel's contract")!));

      final size = tester.getSize(find.byType(NoteMarkdownView));
      expect(size.width, lessThanOrEqualTo(360));
    });

    testWidgets('long wrapped bullets do not overflow at 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NoteMarkdownView(
              text: '- ${List.filled(60, 'wrapping words').join(' ')}',
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('maxBlocks draws only the first blocks', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: NoteMarkdownView(text: _example, maxBlocks: 2)),
      ));
      expect(find.text('Flat and Contract Updates'), findsOneWidget);
      expect(find.text("Daniel's contract"), findsOneWidget);
      expect(find.text('Park Street flat'), findsNothing);
    });
  });

  group('task lists', () {
    const steps = '**Next steps**\n\n- [ ] Email Daniel the contract before Friday.\n'
        '* [x] Send the documents.\n- [X] Book the viewing\n  for Sunday.\n- [ ] Decide by the 10th.';

    test('task lines are task blocks with their state and their index among the tasks', () {
      final blocks = parseNoteMarkdown(steps);
      expect(blocks.map((b) => b.kind).toList(), [
        NoteBlockKind.title,
        NoteBlockKind.task,
        NoteBlockKind.task,
        NoteBlockKind.task,
        NoteBlockKind.task,
      ]);
      final tasks = blocks.skip(1).toList();
      expect(tasks.map((b) => b.text).toList(), [
        'Email Daniel the contract before Friday.',
        'Send the documents.',
        'Book the viewing for Sunday.',
        'Decide by the 10th.',
      ]);
      expect(tasks.map((b) => b.checked).toList(), [false, true, true, false]);
      expect(tasks.map((b) => b.taskIndex).toList(), [0, 1, 2, 3]);
      expect(blocks.first.checked, isFalse);
      expect(blocks.first.taskIndex, isNull);
    });

    test('a bullet, a bracket inside a bullet and a box without text are not tasks', () {
      final blocks = parseNoteMarkdown('- plain\n- see [x] here\n- [ ]\n-[ ] tight');
      expect(blocks.map((b) => b.kind).toSet(), isNot(contains(NoteBlockKind.task)));
    });

    test('plainNotePreview shows task text without the box', () {
      expect(plainNotePreview('**Plan**\n- [ ] Call Ana.\n- [x] Buy milk.'), 'Plan Call Ana. Buy milk.');
    });

    test('never drops a word from a note with tasks', () {
      List<String> withoutMarkers(String input) => _words(input
          .split('\n')
          .map((l) => l.trim().replaceFirst(RegExp(r'^[-*]\s+\[[ xX]\]\s+'), '').replaceFirst(RegExp(r'^[-*•]\s+'), '')
              .replaceAll('*', ''))
          .join(' '));
      for (final input in [steps, '- [ ] a **b** c\n  d\n- [x] e\n\nf g', '**T**\n\nNo next steps were mentioned.']) {
        expect(_blockWords(parseNoteMarkdown(input)), withoutMarkers(input), reason: input);
      }
    });

    group('setTaskChecked', () {
      test('ticks or unticks the first, a middle and the last task and changes nothing else', () {
        final first = setTaskChecked(steps, 0, true);
        expect(first, steps.replaceFirst('- [ ] Email', '- [x] Email'));
        final middle = setTaskChecked(steps, 1, false);
        expect(middle, steps.replaceFirst('* [x] Send', '* [ ] Send'));
        final last = setTaskChecked(steps, 3, true);
        expect(last, steps.replaceFirst('- [ ] Decide', '- [x] Decide'));
        for (final changed in [first, middle, last]) {
          expect(changed.length, steps.length);
          var differences = 0;
          for (var i = 0; i < steps.length; i++) {
            if (steps[i] != changed[i]) differences++;
          }
          expect(differences, 1);
        }
        expect(parseNoteMarkdown(last).last.checked, isTrue);
      });

      test('a task already in the wanted state, an out-of-range index or a note without tasks is unchanged', () {
        expect(setTaskChecked(steps, 2, true), steps, reason: 'a capital X stays');
        expect(setTaskChecked(steps, 0, false), steps);
        expect(setTaskChecked(steps, 4, true), steps);
        expect(setTaskChecked(steps, -1, true), steps);
        expect(setTaskChecked(_example, 0, true), _example);
      });

      test('keeps Windows line ends and indentation', () {
        const text = '**T**\r\n  - [ ] one\r\n- [ ] two\r\n';
        expect(setTaskChecked(text, 1, true), '**T**\r\n  - [ ] one\r\n- [x] two\r\n');
        expect(setTaskChecked(text, 0, true), '**T**\r\n  - [x] one\r\n- [ ] two\r\n');
      });
    });

    group('view', () {
      Future<void> pump(WidgetTester tester, String text, {void Function(int, bool)? onTaskToggled}) =>
          tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 360, child: NoteMarkdownView(text: text, onTaskToggled: onTaskToggled)),
            ),
          ));

      testWidgets('tasks render as checkbox rows without the Markdown box; done ones are struck through',
          (tester) async {
        await pump(tester, steps);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('['), findsNothing);
        expect(find.byType(Checkbox), findsNothing, reason: 'custom-drawn, not the Material checkbox');
        expect(find.byKey(const Key('note_task_box_0')), findsOneWidget);
        expect(find.byKey(const Key('note_task_box_3')), findsOneWidget);
        expect(_styleOf(tester, 'Send the documents.')?.decoration, TextDecoration.lineThrough);
        expect(_styleOf(tester, 'Decide by the 10th.')?.decoration, isNot(TextDecoration.lineThrough));
        expect(_styleOf(tester, 'Send the documents.')?.color, isNot(NoteMarkdownView.defaultStyle.color));
      });

      testWidgets('tapping a task reports its index and the new state; each row is at least 44 dp tall',
          (tester) async {
        final taps = <String>[];
        await pump(tester, steps, onTaskToggled: (i, checked) => taps.add('$i $checked'));

        await tester.tap(find.text('Decide by the 10th.'));
        await tester.tap(find.text('Send the documents.'));
        await tester.tap(find.byKey(const Key('note_task_box_0')));

        expect(taps, ['3 true', '1 false', '0 true']);
        expect(tester.getSize(find.byKey(const Key('note_task_3'))).height, greaterThanOrEqualTo(44));
      });

      testWidgets('without a callback the boxes are shown but cannot be tapped', (tester) async {
        await pump(tester, steps);
        expect(find.byKey(const Key('note_task_box_0')), findsOneWidget);
        expect(
          find.descendant(of: find.byKey(const Key('note_task_0')), matching: find.byType(GestureDetector)),
          findsNothing,
        );
        await tester.tap(find.text('Decide by the 10th.'), warnIfMissed: false);
        expect(tester.takeException(), isNull);
      });
    });
  });

  test('numbered items stay on separate lines and keep their numbers', () {
    final blocks = parseNoteMarkdown('Steps:\n1. Call the bank.\n2. Send the form.');
    expect(blocks.map((b) => b.kind), everyElement(NoteBlockKind.paragraph));
    expect(blocks.map((b) => b.text), ['Steps:', '1. Call the bank.', '2. Send the form.']);
  });
}
