import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_body.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown.dart';
import 'package:eudemonia/features/synthesis/presentation/note_row.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('noteTextForClipboard', () {
    test('removes heading marks and emphasis, keeps bullets, turns tasks into boxes', () {
      const markdown = '# Flat visit\n\n**Notes**\n- I liked the **big** window\n* second *bullet*\n'
          '- [ ] call the agent\n- [x] book the day\n\nPlain closing line.';
      expect(
        noteTextForClipboard('Flat visit', markdown),
        'Flat visit\n\nNotes\n- I liked the big window\n- second bullet\n[ ] call the agent\n[x] book the day\n\nPlain closing line.',
      );
    });

    test('does not repeat the title when the note starts with it, whichever way it is marked', () {
      expect(noteTextForClipboard('Flat visit', '**Flat visit**\n- body'), 'Flat visit\n\n- body');
      expect(noteTextForClipboard('Flat visit', '## Flat visit\n- body'), 'Flat visit\n\n- body');
    });

    test('puts the title above a note that does not start with it', () {
      expect(noteTextForClipboard('Flat visit', 'I liked the flat.'), 'Flat visit\n\nI liked the flat.');
    });

    test('an empty title copies the note alone; an empty note copies the title alone', () {
      expect(noteTextForClipboard('', '- a\n- b'), '- a\n- b');
      expect(noteTextForClipboard('Only title', ''), 'Only title');
    });

    test('collapses runs of blank lines and trims the ends; keeps a lone star that is not emphasis', () {
      expect(noteTextForClipboard('', '\n\nA\n\n\n\nB  \n'), 'A\n\nB');
      expect(noteTextForClipboard('', '2 * 3 = 6'), '2 * 3 = 6');
    });
  });

  group('noteHeadingTitle', () {
    test('is the title block of the note, null when the note has none', () {
      expect(noteHeadingTitle('**Flat visit**\n- x'), 'Flat visit');
      expect(noteHeadingTitle('Remember to call the plumber'), isNull);
    });
  });

  group('copying a note', () {
    final copied = <String>[];

    setUp(() {
      copied.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    SynthesisCluster note({String content = '**Flat visit**\n\n- I liked the **flat**.'}) => SynthesisCluster(
          clusterId: 'a',
          sequenceNumber: '#S-01',
          folder: 'Work',
          synthesizedContent: content,
          sessionStart: DateTime(2026, 11, 20, 9),
          sessionEnd: DateTime(2026, 11, 20, 9),
          sessionDuration: Duration.zero,
          originNotes: [
            SynthesisOriginNote(
                id: 1, formattedSequence: '#01', cleanedText: 'one', timestamp: DateTime(2026, 11, 20, 9)),
          ],
        );

    Widget body(SynthesisCluster n, {required bool editMode}) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NoteBody(
                note: n,
                editMode: editMode,
                folderNames: const ['Work'],
                canMerge: true,
                onTaskToggled: (_, _) {},
                onToggleThoughts: () {},
                onFolderChanged: (_) {},
                onStyle: () {},
                onEditText: () {},
                onMerge: () {},
                onDelete: () {},
                onMoveOut: (_) {},
              ),
            ),
          ),
        );

    for (final editMode in [false, true]) {
      testWidgets('an open note has a Copy control in ${editMode ? 'Edit' : 'Read'} mode that copies title and note as plain text',
          (tester) async {
        await tester.pumpWidget(body(note(), editMode: editMode));

        expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
        await tester.tap(find.byKey(const Key('note_copy_button')));
        await tester.pump();

        expect(copied, ['Flat visit\n\n- I liked the flat.']);
        expect(find.byKey(const Key('copied_snackbar')), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      });
    }

    testWidgets('a long press on the open note body copies it too', (tester) async {
      await tester.pumpWidget(body(note(), editMode: false));

      await tester.longPress(find.textContaining('I liked the'));
      await tester.pump();

      expect(copied, ['Flat visit\n\n- I liked the flat.']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a long press on a row copies; a tap still only toggles', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteRow(
            clusterId: 'a',
            number: '#S-01',
            title: 'Flat visit',
            timeLabel: '09:00 AM',
            unread: false,
            open: false,
            onTap: () => taps++,
            onLongPress: () => copied.add('long'),
          ),
        ),
      ));

      await tester.tap(find.byKey(noteRowKey('a')));
      expect(taps, 1);
      await tester.longPress(find.byKey(noteRowKey('a')));
      expect(copied, ['long']);
      expect(taps, 1);
    });
  });
}
