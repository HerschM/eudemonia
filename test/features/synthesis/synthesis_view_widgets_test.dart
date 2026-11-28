import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/folder_panel.dart';
import 'package:eudemonia/features/synthesis/presentation/note_action_row.dart';
import 'package:eudemonia/features/synthesis/presentation/note_body.dart';
import 'package:eudemonia/features/synthesis/presentation/note_row.dart';
import 'package:eudemonia/features/synthesis/presentation/note_text_editor.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/raw_thoughts_list.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_bar.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_filtering.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

import 'notes_view_test_support.dart';

SynthesisOriginNote _thought(int id, String text, {int minute = 0}) => SynthesisOriginNote(
      id: id,
      formattedSequence: '#0$id',
      cleanedText: text,
      timestamp: DateTime(2026, 11, 26, 14, 35 + minute),
    );

SynthesisCluster _note({
  String id = 'a',
  String number = '#S-02',
  String content = '**Flat visit**\n\n- I liked the flat.',
  String folder = 'Work',
  bool unread = false,
  String style = defaultNoteStyleId,
  List<SynthesisOriginNote>? thoughts,
  bool expanded = false,
  DateTime? start,
}) =>
    SynthesisCluster(
      clusterId: id,
      sequenceNumber: number,
      folder: folder,
      synthesizedContent: content,
      sessionStart: start ?? DateTime(2026, 11, 26, 14, 35),
      sessionEnd: DateTime(2026, 11, 26, 14, 45),
      sessionDuration: const Duration(minutes: 10),
      originNotes: thoughts ?? [_thought(1, 'First thought'), _thought(2, 'Second thought', minute: 4)],
      appliedStyleId: style,
      isUnread: unread,
      isExpanded: expanded,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('note titles and times', () {
    test('a note is listed under its title block, else its first eight words', () {
      expect(noteListTitle('**Flat visit**\n\n- I liked the flat.'), 'Flat visit');
      expect(noteListTitle('One two three four five six seven eight nine ten'), 'One two three four five six seven eight…');
      expect(noteListTitle('Three little words'), 'Three little words');
      expect(noteListTitle('Intro line\n\n**Later title**\n- x'), 'Intro line Later title x',
          reason: 'a title that is not the first block is not the title');
      expect(noteListTitle('   '), 'Empty note');
    });

    test('the row shows the time of day, the body the date and the session length', () {
      expect(formatNoteTime(DateTime(2026, 11, 26, 14, 35)), '02:35 PM');
      expect(formatNoteTime(DateTime(2026, 11, 26, 0, 5)), '12:05 AM');
      expect(describeNoteOrigin(1), 'From 1 thought');
      expect(describeNoteOrigin(3), 'From 3 thoughts');
    });
  });

  group('filtering', () {
    final today = DateTime(2026, 11, 26, 9);
    final older = DateTime(2026, 11, 25, 9);
    final notes = [
      _note(id: 'a', number: '#S-01', folder: 'Work', unread: true, start: today),
      _note(id: 'b', number: '#S-02', folder: 'work', start: today),
      _note(id: 'c', number: '#S-01', folder: 'Garden', start: older),
    ];

    test('newest day first, the highest number first inside a day, folder names compared without case', () {
      expect([for (final n in visibleNotes(notes)) n.clusterId], ['b', 'a', 'c']);
      expect([for (final n in visibleNotes(notes, folder: 'Work')) n.clusterId], ['b', 'a']);
      expect([for (final n in visibleNotes(notes, triage: SynthesisTriage.unread)) n.clusterId], ['a']);
      expect([for (final n in visibleNotes(notes, triage: SynthesisTriage.read)) n.clusterId], ['b', 'c']);
    });

    test('folder counts follow the folder list, then folders that still hold notes', () {
      final counts = folderCounts(notes, ['Work', 'Journal']);
      expect([for (final c in counts) c.name], ['Work', 'Journal', 'Garden']);
      expect([for (final c in counts) c.count], [2, 0, 1]);
      expect([for (final c in counts) c.unread], [1, 0, 0]);
    });
  });

  group('NoteRow', () {
    Widget row({
      bool open = false,
      bool unread = true,
      bool rewriting = false,
      String? folderLabel,
      String title = 'Flat visit',
      VoidCallback? onTap,
      Widget? body,
    }) =>
        NoteRow(
          clusterId: 'a',
          number: '#S-02',
          title: title,
          timeLabel: '02:35 PM',
          unread: unread,
          open: open,
          rewriting: rewriting,
          folderLabel: folderLabel,
          onTap: onTap ?? () {},
          body: body,
        );

    testWidgets('shows number, title, time, unread dot and chevron in one compact row', (tester) async {
      await _pump(tester, row(folderLabel: 'Work'));

      expect(find.text('#S-02'), findsOneWidget);
      expect(find.text('Flat visit'), findsOneWidget);
      expect(find.text('02:35 PM'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.byKey(const Key('unread_dot_a')), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('note_row_a'))).height, inInclusiveRange(56, 64));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long title ends in an ellipsis instead of overflowing 360 dp', (tester) async {
      await _pump(tester, row(title: 'An extraordinarily long title that cannot possibly fit on a single narrow row', folderLabel: 'Uncategorized'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a note being rewritten shows the thinking indicator in place of the time', (tester) async {
      await _pump(tester, row(rewriting: true));

      expect(find.byType(ThinkingIndicator), findsOneWidget);
      expect(find.text('Rewriting…'), findsOneWidget);
      expect(find.text('02:35 PM'), findsNothing);
    });

    testWidgets('the body is built only while the row is open, and the tap reaches the callback', (tester) async {
      var taps = 0;
      await _pump(tester, row(onTap: () => taps++, body: const Text('BODY')));
      expect(find.text('BODY'), findsNothing);

      await tester.tap(find.byKey(const Key('note_row_a')));
      expect(taps, 1);

      await _pump(tester, row(open: true, body: const Text('BODY')));
      await tester.pumpAndSettle();
      expect(find.text('BODY'), findsOneWidget);
    });
  });

  group('SynthesisBar', () {
    Widget bar({
      String folderLabel = 'All notes',
      bool filterActive = false,
      bool readMode = true,
      bool allOpen = false,
      VoidCallback? onFolderTap,
      VoidCallback? onToggleAll,
      ValueChanged<bool>? onReadModeChanged,
    }) =>
        SynthesisBar(
          folderLabel: folderLabel,
          filterActive: filterActive,
          readMode: readMode,
          allOpen: allOpen,
          onFolderTap: onFolderTap ?? () {},
          onToggleAll: onToggleAll ?? () {},
          onReadModeChanged: onReadModeChanged ?? (_) {},
        );

    testWidgets('fits one row at 360 dp, also with a long folder name and the filter badge', (tester) async {
      await _pump(tester, bar(folderLabel: 'Home improvement and gardening', filterActive: true));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('synthesis_filter_badge')), findsOneWidget);
      final folder = tester.getRect(find.byKey(const Key('synthesis_folder_button')));
      final mode = tester.getRect(find.byKey(const Key('synthesis_mode_toggle')));
      expect(folder.right, lessThanOrEqualTo(mode.left));
      expect((folder.center.dy - mode.center.dy).abs(), lessThan(8), reason: 'one row');
      expect(mode.height, lessThan(48));
      expect(tester.getRect(find.byKey(const Key('synthesis_expand_all_toggle'))).right, lessThanOrEqualTo(mode.left));
      expect(mode.right, lessThanOrEqualTo(360));
    });

    testWidgets('the folder button names the selection and the badge shows only while a filter is on', (tester) async {
      await _pump(tester, bar());
      expect(find.text('All notes'), findsOneWidget);
      expect(find.byKey(const Key('synthesis_filter_badge')), findsNothing);
    });

    testWidgets('Read | Edit has book and pencil icons, semantic labels, and reports the chosen mode', (tester) async {
      final modes = <bool>[];
      await _pump(tester, bar(onReadModeChanged: modes.add));

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('Read mode'), findsOneWidget);
      expect(find.bySemanticsLabel('Edit mode'), findsOneWidget);

      await tester.tap(find.byKey(const Key('synthesis_mode_edit')));
      await tester.tap(find.byKey(const Key('synthesis_mode_read')));
      expect(modes, [false, true]);
    });

    testWidgets('the toggle says open all, or collapse all once everything is open', (tester) async {
      var taps = 0;
      await _pump(tester, bar(onToggleAll: () => taps++));
      expect(find.byTooltip('Open all'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
      await tester.tap(find.byKey(const Key('synthesis_expand_all_toggle')));
      expect(taps, 1);

      await _pump(tester, bar(allOpen: true));
      expect(find.byTooltip('Collapse all'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_less), findsOneWidget);
    });
  });

  group('FolderPanel', () {
    FolderPanel panel({
      SynthesisTriage triage = SynthesisTriage.all,
      String? selected,
      List<SynthesisTriage>? triages,
      List<String>? picked,
      VoidCallback? onManage,
      VoidCallback? onAdd,
    }) =>
        FolderPanel(
          triage: triage,
          onTriageChanged: (t) => triages?.add(t),
          selectedFolder: selected,
          totalCount: 7,
          totalUnread: 3,
          folders: const [
            FolderCount(name: 'Work', count: 4, unread: 2),
            FolderCount(name: 'Journal', count: 0, unread: 0),
            FolderCount(name: 'Garden', count: 3, unread: 1),
          ],
          onSelectAll: () => picked?.add('<all>'),
          onSelectFolder: (n) => picked?.add(n),
          onManageFolders: onManage ?? () {},
          onAddFolder: onAdd ?? () {},
        );

    testWidgets('shows All notes and every folder with counts and an unread badge, nothing wrong at 360 dp',
        (tester) async {
      await _pump(tester, SizedBox(width: 288, child: panel()));

      String countOf(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
      expect(countOf('folder_panel_all_notes_count'), '7');
      expect(countOf('folder_panel_row_Work_count'), '4');
      expect(countOf('folder_panel_row_Journal_count'), '0');
      expect(find.byKey(const Key('folder_panel_all_notes_unread')), findsOneWidget);
      expect(find.byKey(const Key('folder_panel_row_Work_unread')), findsOneWidget);
      expect(find.byKey(const Key('folder_panel_row_Journal_unread')), findsNothing, reason: 'no unread, no badge');
      expect(find.text('Manage folders'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the footer has a + (New folder) beside Manage folders; each reports its own tap (TASK-106 B)',
        (tester) async {
      var manage = 0;
      var add = 0;
      await _pump(tester, SizedBox(width: 288, height: 600, child: panel(onManage: () => manage++, onAdd: () => add++)));

      expect(find.byTooltip('New folder'), findsOneWidget);
      final link = tester.getRect(find.byKey(const Key('manage_folders_link')));
      final plus = tester.getRect(find.byKey(const Key('folder_panel_add')));
      expect(plus.left, greaterThanOrEqualTo(link.right), reason: 'beside Manage folders');
      expect(plus.right, lessThanOrEqualTo(288));
      await tester.tap(find.byKey(const Key('folder_panel_add')));
      expect((manage, add), (0, 1));
      await tester.tap(find.byKey(const Key('manage_folders_link')));
      expect((manage, add), (1, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('triage chips, rows and the footer link report what was chosen', (tester) async {
      final triages = <SynthesisTriage>[];
      final picked = <String>[];
      var manage = 0;
      await _pump(tester, SizedBox(width: 288, child: panel(triages: triages, picked: picked, onManage: () => manage++)));

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      await tester.tap(find.byKey(const Key('triage_chip_unread')));
      await tester.tap(find.byKey(const Key('triage_chip_read')));
      expect(triages, [SynthesisTriage.unread, SynthesisTriage.read]);

      await tester.tap(find.byKey(const Key('folder_panel_row_Garden')));
      await tester.tap(find.byKey(const Key('folder_panel_all_notes')));
      expect(picked, ['Garden', '<all>']);

      await tester.tap(find.byKey(const Key('manage_folders_link')));
      expect(manage, 1);
    });
  });

  group('FolderPanelOverlay', () {
    Widget overlay({required bool open, VoidCallback? onDismiss}) => FolderPanelOverlay(
          open: open,
          onDismiss: onDismiss ?? () {},
          panel: const Material(key: Key('panel_stub'), child: Text('PANEL')),
          child: const ColoredBox(key: Key('list_stub'), color: Colors.black),
        );

    testWidgets('closed it builds only the list; open it slides in at 80 % of the width', (tester) async {
      await _pump(tester, overlay(open: false));
      expect(find.byKey(const Key('panel_stub')), findsNothing);
      expect(find.byKey(const Key('folder_panel_scrim')), findsNothing);

      await _pump(tester, overlay(open: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getRect(find.byKey(const Key('panel_stub'))).left, lessThan(0), reason: 'still sliding in');
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('panel_stub')));
      expect(rect.left, 0);
      expect(rect.width, closeTo(288, 0.5), reason: '80 % of 360 dp');
    });

    testWidgets('on a wide screen the panel stops at 320 dp', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: overlay(open: true))));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('panel_stub'))).width, 320);
    });

    testWidgets('a tap on the scrim dismisses; the list keeps its place under the panel', (tester) async {
      var dismissed = 0;
      await _pump(tester, overlay(open: true, onDismiss: () => dismissed++));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(340, 400));
      expect(dismissed, 1);
      await tester.tap(find.byKey(const Key('panel_stub')));
      expect(dismissed, 1, reason: 'a tap on the panel itself is not on the scrim');
      expect(find.byKey(const Key('list_stub')), findsOneWidget);
    });

    testWidgets('closing slides it away and removes it', (tester) async {
      await _pump(tester, overlay(open: true));
      await tester.pumpAndSettle();
      await _pump(tester, overlay(open: false));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panel_stub')), findsNothing);
    });
  });

  group('NoteBody', () {
    NoteBody body(
      SynthesisCluster note, {
      bool editMode = false,
      bool canMerge = true,
      List<String>? events,
    }) {
      final log = events;
      return NoteBody(
        note: note,
        editMode: editMode,
        folderNames: const ['Work', 'Garden'],
        canMerge: canMerge,
        onTaskToggled: (i, c) => log?.add('task $i $c'),
        onToggleThoughts: () => log?.add('thoughts'),
        onFolderChanged: (f) => log?.add('folder $f'),
        onStyle: () => log?.add('style'),
        onEditText: () => log?.add('edit'),
        onMerge: () => log?.add('merge'),
        onDelete: () => log?.add('delete'),
        onMoveOut: (t) => log?.add('moveout ${t.id}'),
      );
    }

    testWidgets('Read mode: the formatted note and the quiet link, no edit control', (tester) async {
      await _pump(tester, SingleChildScrollView(child: body(_note())));

      // The title is the row's to show; the body does not repeat it (TASK-093, user review 2026-11-27).
      expect(find.text('Flat visit'), findsNothing);
      expect(find.text('I liked the flat.'), findsOneWidget);
      expect(find.textContaining('*'), findsNothing);
      expect(find.text('From 2 thoughts'), findsOneWidget);
      expect(find.text('26/11  02:35 PM • ⏱️ 10m session'), findsOneWidget);
      for (final key in ['cluster_folder_dropdown_a', 'style_button_a', 'edit_text_button_a', 'merge_button_a', 'delete_cluster_a']) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(find.byKey(const Key('hand_edited_notice_a')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Read mode: the link reveals the thoughts as a plain list with number, time and text', (tester) async {
      final events = <String>[];
      await _pump(tester, SingleChildScrollView(child: body(_note(expanded: true), events: events)));

      expect(find.text('ORIGIN RAW NOTES (2)'), findsOneWidget);
      expect(find.text('#01'), findsOneWidget);
      expect(find.text('02:35 PM'), findsOneWidget);
      expect(find.text('First thought'), findsOneWidget);
      expect(find.text('02:39 PM'), findsOneWidget);
      expect(find.text('Move Out'), findsNothing);

      await tester.tap(find.byKey(const Key('expand_raw_notes_a')));
      expect(events, ['thoughts']);
    });

    testWidgets('Edit mode: the action row with the style label on the Style control', (tester) async {
      await _pump(tester, SingleChildScrollView(child: body(_note(style: 'concise'), editMode: true)));

      expect(find.byKey(const Key('cluster_folder_dropdown_a')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.text('Short summary')), findsOneWidget);
      expect(find.byKey(const Key('edit_text_button_a')), findsOneWidget);
      expect(find.byKey(const Key('merge_button_a')), findsOneWidget);
      expect(find.byKey(const Key('delete_cluster_a')), findsOneWidget);
      expect(find.byKey(const Key('hand_edited_notice_a')), findsNothing);
      expect(tester.takeException(), isNull, reason: 'the five controls wrap at 360 dp');
    });

    testWidgets('Edit mode: the longest style label and a long folder name still fit 360 dp', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: NoteBody(
            note: _note(style: 'actionable', folder: 'Home improvement project'),
            editMode: true,
            folderNames: const ['Home improvement project'],
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
      );
      expect(find.text('Actionable next steps'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Edit mode: merge is offered only when there is another note', (tester) async {
      await _pump(tester, SingleChildScrollView(child: body(_note(), editMode: true, canMerge: false)));
      expect(find.byKey(const Key('merge_button_a')), findsNothing);
    });

    testWidgets('Edit mode: a hand-edited note says so under the actions and labels its style', (tester) async {
      await _pump(tester, SingleChildScrollView(child: body(_note(style: manualStyleId), editMode: true)));

      expect(find.text('Edited by hand. It is not rewritten automatically; new thoughts are added underneath.'),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.text('Edited by hand')), findsOneWidget);
    });

    testWidgets('Edit mode: every action reaches its callback', (tester) async {
      final events = <String>[];
      await _pump(tester, SingleChildScrollView(child: body(_note(expanded: true), editMode: true, events: events)));

      await tester.tap(find.byKey(const Key('style_button_a')));
      await tester.tap(find.byKey(const Key('edit_text_button_a')));
      await tester.tap(find.byKey(const Key('merge_button_a')));
      await tester.tap(find.byKey(const Key('delete_cluster_a')));
      await tester.tap(find.byKey(const Key('move_out_note_1')));
      expect(events, ['style', 'edit', 'merge', 'delete', 'moveout 1']);

      // User decision 2026-11-28 (point 9): the folder menu is a chooser sheet with a search field.
      await tester.tap(find.byKey(const Key('cluster_folder_dropdown_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_option_Garden')));
      await tester.pumpAndSettle();
      expect(events.last, 'folder Garden');
    });

    testWidgets('a checklist can be ticked in either mode', (tester) async {
      final events = <String>[];
      final note = _note(content: '**Errands**\n\n- [ ] Call.\n- [x] Buy.');
      await _pump(tester, SingleChildScrollView(child: body(note, events: events)));

      await tester.tap(find.byKey(const Key('note_task_0')));
      await tester.tap(find.byKey(const Key('note_task_1')));
      expect(events, ['task 0 true', 'task 1 false']);
    });
  });

  group('RawThoughtsList', () {
    testWidgets('a note of one thought has no Move Out even when moving is allowed', (tester) async {
      await _pump(tester, SingleChildScrollView(child: RawThoughtsList(thoughts: [_thought(1, 'Only')], onMoveOut: (_) {})));
      expect(find.text('Only'), findsOneWidget);
      expect(find.text('Move Out'), findsNothing);
    });

    // User decision 2026-11-28 (TASK-108 B, point 14): tapping a raw thought goes back to it in Capture.
    testWidgets('with onOpenThought a tap on the whole row reports the thought id; Move Out stays its own button',
        (tester) async {
      final opened = <int>[];
      final moved = <int>[];
      await _pump(
        tester,
        SingleChildScrollView(
          child: RawThoughtsList(
            thoughts: [_thought(7, 'One'), _thought(8, 'Two')],
            onMoveOut: (t) => moved.add(t.id),
            onOpenThought: opened.add,
          ),
        ),
      );
      expect(find.byTooltip('Open in Capture'), findsNWidgets(2));

      await tester.tap(find.text('Two'));
      expect(opened, [8]);
      await tester.tap(find.byKey(const Key('raw_thought_open_7')), warnIfMissed: false);
      expect(opened, [8, 7]);

      await tester.tap(find.byKey(const Key('move_out_note_7')));
      expect(moved, [7]);
      expect(opened, [8, 7], reason: 'Move Out does not open the thought');
    });

    testWidgets('without onOpenThought a thought is not tappable and shows no arrow', (tester) async {
      await _pump(tester, SingleChildScrollView(child: RawThoughtsList(thoughts: [_thought(7, 'One'), _thought(8, 'Two')])));
      expect(find.byKey(const Key('raw_thought_open_7')), findsNothing);
      expect(find.byTooltip('Open in Capture'), findsNothing);
    });

    testWidgets('without onMoveOut the list is read only', (tester) async {
      await _pump(tester, SingleChildScrollView(child: RawThoughtsList(thoughts: [_thought(1, 'One'), _thought(2, 'Two')])));
      expect(find.text('Move Out'), findsNothing);
    });
  });

  // User decision 2026-11-28 (TASK-108 A, point 8): a note's text is edited in place, not in a
  // full-height sheet. What the sheet's tests asserted about outcomes moved here (the text handed
  // over on Save, nothing on Cancel, the refusal of an empty text and its message clearing as the
  // user types); the sheet's title and full-height assertions went with the sheet.
  group('NoteTextEditor', () {
    Future<void> open(WidgetTester tester, Future<bool> Function(String) onSave, {List<String>? events}) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: NoteTextEditor(
            initialText: '**Flat**\n- one',
            onSave: onSave,
            onCancel: () => events?.add('cancel'),
            onChanged: (text) => events?.add('changed $text'),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('holds the raw Markdown in a focused multi-line field with the cursor at its end', (tester) async {
      await open(tester, (_) async => true);

      final field = tester.widget<TextField>(find.byKey(const Key('note_edit_field')));
      expect(field.controller!.text, '**Flat**\n- one');
      expect(field.controller!.selection, const TextSelection.collapsed(offset: 14));
      expect(field.maxLines, greaterThan(1));
      expect(field.focusNode?.hasFocus ?? true, isTrue);
      expect(find.byKey(const Key('note_edit_save')), findsOneWidget);
      expect(find.byKey(const Key('note_edit_cancel')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Save hands over the text; Cancel reports cancel and saves nothing', (tester) async {
      final saved = <String>[];
      final events = <String>[];
      await open(tester, (text) async {
        saved.add(text);
        return true;
      }, events: events);
      await tester.tap(find.byKey(const Key('note_edit_cancel')));
      await tester.pump();
      expect(events, ['cancel']);
      expect(saved, isEmpty);

      await tester.enterText(find.byKey(const Key('note_edit_field')), 'My text');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pump();
      expect(saved, ['My text']);
      expect(events, contains('changed My text'));
    });

    testWidgets('is scrolled into view when it opens below the fold and again when the keyboard comes up', (tester) async {
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                const SizedBox(height: 300),
                NoteTextEditor(initialText: 'text', onSave: (_) async => true, onCancel: () {}),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectOnScreen(double bottom) {
        for (final key in ['note_edit_field', 'note_edit_cancel', 'note_edit_save']) {
          final rect = tester.getRect(find.byKey(Key(key)));
          expect(rect.top, greaterThanOrEqualTo(0), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(bottom), reason: key);
        }
      }

      expectOnScreen(400);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expectOnScreen(200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused text shows "A note cannot be empty." and keeps the editor and the typing', (tester) async {
      await open(tester, (_) async => false);

      await tester.enterText(find.byKey(const Key('note_edit_field')), '');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();
      expect(find.text('A note cannot be empty.'), findsOneWidget);
      expect(find.byKey(const Key('note_edit_field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('note_edit_field')), 'x');
      await tester.pump();
      expect(find.text('A note cannot be empty.'), findsNothing, reason: 'typing clears the message');
    });
  });

  group('NotesViewPrefs', () {
    ProviderContainer container(InMemoryNotesViewPrefsStore store) {
      final c = ProviderContainer(overrides: [notesViewPrefsStoreProvider.overrideWithValue(store)]);
      addTearDown(c.dispose);
      return c;
    }

    test('default: Read mode, notes shown as a list of titles', () {
      final prefs = container(InMemoryNotesViewPrefsStore()).read(notesViewPrefsProvider);
      expect(prefs.readMode, isTrue);
      expect(prefs.notesOpenByDefault, isFalse);
    });

    test('the stored values are loaded', () async {
      final c = container(InMemoryNotesViewPrefsStore(const NotesViewPrefs(readMode: false, notesOpenByDefault: true)));
      c.read(notesViewPrefsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(notesViewPrefsProvider).readMode, isFalse);
      expect(c.read(notesViewPrefsProvider).notesOpenByDefault, isTrue);
    });

    test('a change is kept and saved, and a late load does not undo it', () async {
      final store = InMemoryNotesViewPrefsStore(const NotesViewPrefs());
      final c = container(store);
      c.read(notesViewPrefsProvider.notifier).setReadMode(false);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(notesViewPrefsProvider).readMode, isFalse);
      expect(store.stored!.readMode, isFalse);

      c.read(notesViewPrefsProvider.notifier).setNotesOpenByDefault(true);
      await Future<void>.delayed(Duration.zero);
      expect(store.stored!.notesOpenByDefault, isTrue);
      expect(store.stored!.readMode, isFalse);
    });
  });

  group('NoteActionRow', () {
    testWidgets('a folder that is not in the list is still offered for the note that is in it', (tester) async {
      await _pump(
        tester,
        NoteActionRow(
          clusterId: 'a',
          folder: 'Ideas',
          folderNames: const ['Work', 'Uncategorized'],
          styleLabel: 'Organised',
          canMerge: true,
          onFolderChanged: (_) {},
          onStyle: () {},
          onEditText: () {},
          onMerge: () {},
          onDelete: () {},
        ),
      );
      // User decision 2026-11-28 (point 9): the folder menu is a chooser sheet; the note's own folder
      // is still offered, last, and marked as the current one.
      expect(find.descendant(of: find.byKey(const Key('cluster_folder_dropdown_a')), matching: find.text('Ideas')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cluster_folder_dropdown_a')));
      await tester.pumpAndSettle();
      final offered = [
        for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('folder_option_')).evaluate())
          (e.widget.key as ValueKey<String>).value.substring('folder_option_'.length),
      ];
      expect(offered, ['Work', 'Uncategorized', 'Ideas']);
      expect(find.descendant(of: find.byKey(const Key('folder_option_Ideas')), matching: find.byIcon(Icons.check)), findsOneWidget);
    });
  });
}
