import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_action_row.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown_view.dart';
import 'package:eudemonia/features/synthesis/presentation/note_row.dart';
import 'package:eudemonia/features/synthesis/presentation/rewrite_confirmation.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_filtering.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_notices.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_view.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// TASK-093 (user review of 2026-11-27): title shown once, icons, delete wording, the list's end
// clear of the record capsule.

SynthesisCluster _note(String id, String content, {bool unread = false}) => SynthesisCluster(
      clusterId: id,
      sequenceNumber: '#S-01',
      folder: 'Work',
      synthesizedContent: content,
      sessionStart: DateTime(2026, 11, 26, 14, 35),
      sessionEnd: DateTime(2026, 11, 26, 14, 45),
      sessionDuration: Duration.zero,
      originNotes: [
        SynthesisOriginNote(id: 1, formattedSequence: '#01', cleanedText: 'one', timestamp: DateTime(2026, 11, 26, 14, 35)),
      ],
      isUnread: unread,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

SynthesisView _view(List<SynthesisCluster> notes, {bool open = true, Set<String> keptIds = const {}, SynthesisTriage triage = SynthesisTriage.all}) =>
    SynthesisView(
      notes: notes,
      folderNames: const ['Work'],
      folder: null,
      triage: triage,
      keptIds: keptIds,
      readMode: true,
      panelOpen: false,
      isOpen: (_) => open,
      hasWritingModel: true,
      pendingThoughts: 0,
      synthesisBusy: false,
      onFolderButton: () {},
      onDismissPanel: () {},
      onToggleAll: (_, _) {},
      onReadModeChanged: (_) {},
      onSelectAllNotes: () {},
      onSelectFolder: (_) {},
      onTriageChanged: (_) {},
      onManageFolders: () {},
      onAddFolder: () {},
      onChooseModel: () {},
      onSynthesizeNow: () {},
      onToggleNote: (_) {},
      onNoteRead: (_) {},
      onTaskToggled: (_, _, _) {},
      onToggleThoughts: (_) {},
      onFolderChanged: (_, _) {},
      onStyle: (_) {},
      onEditText: (_) {},
      onMerge: (_) {},
      onDelete: (_) {},
      onMoveOut: (_, _) {},
    );

void main() {
  group('the title is shown once', () {
    testWidgets('hideTitle drops only a leading title block', (tester) async {
      await _pump(tester, const NoteMarkdownView(text: '**Flat visit**\n\n- I liked the flat.', hideTitle: true));
      expect(find.text('Flat visit'), findsNothing);
      expect(find.text('I liked the flat.'), findsOneWidget);

      await _pump(tester, const NoteMarkdownView(text: 'Plain words only.', hideTitle: true));
      expect(find.text('Plain words only.'), findsOneWidget, reason: 'no title block: the first words stay in the body');

      await _pump(tester, const NoteMarkdownView(text: '**Flat visit**\n- x'));
      expect(find.text('Flat visit'), findsOneWidget, reason: 'off by default');
    });

    testWidgets('an open row wraps its whole title; a closed row keeps one line with an ellipsis', (tester) async {
      Widget row(bool open) => NoteRow(
            clusterId: 'a',
            number: '#S-01',
            title: 'A long title that needs more than one line on a narrow row of a phone',
            timeLabel: '02:35 PM',
            unread: false,
            open: open,
            onTap: () {},
          );
      Text title() => tester.widget<Text>(find.textContaining('A long title'));

      await _pump(tester, row(false));
      expect(title().maxLines, 1);
      expect(title().overflow, TextOverflow.ellipsis);

      await _pump(tester, row(true));
      expect(title().maxLines, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the list an open note shows its title once; a note without a title block keeps its text in the body',
        (tester) async {
      await _pump(tester, _view([_note('a', '**Flat visit**\n\n- I liked the flat.'), _note('b', 'Call the plumber about the tap.')]));
      expect(find.text('Flat visit'), findsOneWidget);
      expect(find.text('I liked the flat.'), findsOneWidget);
      // Row title (first words) and the body's paragraph both show: nothing is dropped from it.
      expect(find.text('Call the plumber about the tap.'), findsNWidgets(2));
    });
  });

  group('icons: no stars', () {
    testWidgets('Style chip, notices and the thinking indicator use the new icons', (tester) async {
      await _pump(
        tester,
        Column(children: [
          NoteActionRow(
            clusterId: 'a',
            folder: 'Work',
            folderNames: const ['Work'],
            styleLabel: 'Organised',
            canMerge: false,
            onFolderChanged: (_) {},
            onStyle: () {},
            onEditText: () {},
            onMerge: () {},
            onDelete: () {},
          ),
          ChooseWritingModelCard(onChoose: () {}),
          const ThinkingIndicator(label: 'Synthesizing…'),
        ]),
      );
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.byIcon(Icons.draw_outlined)), findsOneWidget);
      expect(find.descendant(of: find.byType(ChooseWritingModelCard), matching: find.byIcon(Icons.hub_outlined)), findsOneWidget);
      expect(tester.widget<Icon>(find.byKey(const Key('thinking_spark'))).icon, Icons.hub_outlined);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the Style chip has no violet', (tester) async {
      await _pump(
        tester,
        NoteActionRow(
          clusterId: 'a',
          folder: 'Work',
          folderNames: const ['Work'],
          styleLabel: 'Organised',
          canMerge: false,
          onFolderChanged: (_) {},
          onStyle: () {},
          onEditText: () {},
          onMerge: () {},
          onDelete: () {},
        ),
      );
      final icon = tester.widget<Icon>(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.byIcon(Icons.draw_outlined)));
      expect(icon.color, isNot(AppColors.accentAI));
    });

    testWidgets('the Rewrite button of the hand-edit warning is not violet', (tester) async {
      await _pump(
        tester,
        Builder(builder: (context) => TextButton(onPressed: () => confirmRewriteOfHandEditedNote(context), child: const Text('go'))),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Rewrite'));
      expect(text.style!.color, AppColors.textPrimary);
    });
  });

  group('delete wording', () {
    test('names the note and says its thoughts stay and wait for Synthesis', () {
      expect(deleteNoteQuestion('#S-04', 'Flat visit'), 'Delete note #S-04 "Flat visit"?');
      expect(deleteNoteConsequence(3), 'Its 3 thoughts stay in Capture and become ready for Synthesis again.');
      expect(deleteNoteConsequence(1), 'Its 1 thought stays in Capture and becomes ready for Synthesis again.');
    });
  });

  group('the list', () {
    testWidgets('ends 96 px below the last note, clear of the floating record capsule', (tester) async {
      await _pump(tester, _view([_note('a', '**A**\n- x')]));
      final list = tester.widget<ListView>(find.byType(ListView));
      expect((list.padding! as EdgeInsets).bottom, 96);
    });

    testWidgets('a long press on a closed row copies the note as plain text', (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _pump(tester, _view([_note('a', '**Flat visit**\n\n- I liked the **flat**.')], open: false));
      await tester.longPress(find.byKey(noteRowKey('a')));
      await tester.pump();

      expect(copied, ['Flat visit\n\n- I liked the flat.']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('keptIds keep a note listed under a filter it no longer matches', (tester) async {
      final read = _note('a', '**A**\n- x');
      await _pump(tester, _view([read], triage: SynthesisTriage.unread));
      expect(find.byKey(noteRowKey('a')), findsNothing);

      await _pump(tester, _view([read], triage: SynthesisTriage.unread, keptIds: const {'a'}));
      expect(find.byKey(noteRowKey('a')), findsOneWidget);
    });

    test('visibleNotes adds the kept notes of the folder, whatever their read state', () {
      final a = _note('a', 'x');
      final b = _note('b', 'y', unread: true);
      expect([for (final n in visibleNotes([a, b], triage: SynthesisTriage.unread)) n.clusterId], ['b']);
      expect(
        {for (final n in visibleNotes([a, b], triage: SynthesisTriage.unread, keep: {'a'})) n.clusterId},
        {'a', 'b'},
      );
      expect([for (final n in visibleNotes([a, b], folder: 'Garden', triage: SynthesisTriage.unread, keep: {'a'})) n.clusterId], isEmpty);
    });
  });
}
