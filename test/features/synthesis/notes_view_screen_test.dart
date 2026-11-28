import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/application/session_actions.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/note_action_row.dart';
import 'package:eudemonia/features/synthesis/presentation/note_body.dart';
import 'package:eudemonia/features/synthesis/presentation/note_markdown_view.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';

import '../settings/fake_permission_gateway.dart';
import '../settings/settings_test_harness.dart';
import 'notes_view_test_support.dart';

/// Counts the runs a style choice or a folder move starts; they never finish.
class _Runner implements SynthesisRunner {
  int runs = 0;

  @override
  Future<SynthesisRunResult> run({required bool manual}) async {
    runs++;
    return SynthesisRunResult.busy;
  }

  @override
  bool get isRunning => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

DateTime _at(int daysAgo, [int hour = 10, int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
}

SynthesisCluster _note(
  String id,
  String number,
  DateTime start, {
  String folder = 'Work',
  String content = '**Flat visit**\n\n- I liked the flat.',
  bool unread = false,
  bool reprocessing = false,
  String style = defaultNoteStyleId,
  List<SynthesisOriginNote>? thoughts,
}) =>
    SynthesisCluster(
      clusterId: id,
      sequenceNumber: number,
      folder: folder,
      synthesizedContent: content,
      sessionStart: start,
      sessionEnd: start,
      sessionDuration: Duration.zero,
      originNotes: thoughts ??
          [
            SynthesisOriginNote(id: id.hashCode.abs() % 1000 * 10 + 1, formattedSequence: '#01', cleanedText: 'Thought one of $id', timestamp: start),
            SynthesisOriginNote(id: id.hashCode.abs() % 1000 * 10 + 2, formattedSequence: '#02', cleanedText: 'Thought two of $id', timestamp: start),
          ],
      appliedStyleId: style,
      isUnread: unread,
      isReprocessing: reprocessing,
    );

class _Folders implements FolderStore {
  final List<FolderDefinition> folders;
  _Folders(this.folders);

  @override
  Future<List<FolderDefinition>?> load() async => folders;

  @override
  Future<void> save(List<FolderDefinition> folders) async {}
}

const _userFolders = [
  FolderDefinition(name: 'Work', description: 'the job.'),
  FolderDefinition(name: 'Garden', description: 'plants.'),
  FolderDefinition(name: 'Journal', description: 'feelings.'),
];

void main() {
  late ProviderContainer container;
  late _Runner runner;
  late InMemoryNotesViewPrefsStore prefsStore;

  setUp(mockHardwareChannel);

  Future<void> pumpScreen(
    WidgetTester tester,
    List<SynthesisCluster> clusters, {
    NotesViewPrefs prefs = const NotesViewPrefs(),
    ShellTab? shellTab,
    double height = 1400,
  }) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    runner = _Runner();
    prefsStore = InMemoryNotesViewPrefsStore(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          notesViewPrefsStoreProvider.overrideWithValue(prefsStore),
          folderStoreProvider.overrideWithValue(_Folders(_userFolders)),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
          activeSynthesisProfileProvider.overrideWithValue(ModelCatalogue.qwen3_4b.profile!),
          synthesisRunnerProvider.overrideWithValue(runner),
          if (shellTab != null) selectedShellTabProvider.overrideWith(() => _FixedTab(shellTab)),
        ],
        child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(SynthesisScreen)));
    await container.read(foldersProvider.notifier).loaded;
    await tester.pump();
    await tester.pump(); // the stored view preferences arrive
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  SynthesisCluster stored(String id) => container.read(synthesisRepositoryProvider).firstWhere((c) => c.clusterId == id);

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openRow(WidgetTester tester, String id) => tapAndSettle(tester, find.byKey(Key('note_row_$id')));

  Future<void> editMode(WidgetTester tester) => tapAndSettle(tester, find.byKey(const Key('synthesis_mode_edit')));

  group('the list of titles', () {
    testWidgets('rows show number, title, time and unread dot, grouped by day, newest first', (tester) async {
      await pumpScreen(tester, [
        _note('old', '#S-01', _at(1, 9, 5), content: '**Yesterday plan**\n- x'),
        _note('t1', '#S-01', _at(0, 8, 5), content: '**Early note**\n- x'),
        _note('t2', '#S-02', _at(0, 14, 35), content: '**Flat visit**\n- x', unread: true),
      ]);

      expect(find.textContaining('TODAY —'), findsOneWidget);
      expect(find.textContaining('YESTERDAY —'), findsOneWidget);
      expect(find.text('Flat visit'), findsOneWidget);
      expect(find.text('02:35 PM'), findsOneWidget);
      expect(find.text('#S-02'), findsOneWidget);
      expect(find.byKey(const Key('unread_dot_t2')), findsOneWidget);
      expect(find.byKey(const Key('unread_dot_t1')), findsNothing);
      double top(String id) => tester.getTopLeft(find.byKey(Key('note_row_$id'))).dy;
      expect(top('t2'), lessThan(top('t1')));
      expect(top('t1'), lessThan(top('old')));
      // Closed: no body, no raw thoughts link.
      expect(find.text('I liked the flat.'), findsNothing);
      expect(find.byKey(const Key('expand_raw_notes_t2')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('with All notes selected the folder is a small label under the title; with a folder selected it is not',
        (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), folder: 'Garden')]);

      expect(find.text('Garden'), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tapAndSettle(tester, find.byKey(const Key('folder_panel_row_Garden')));
      expect(find.descendant(of: find.byKey(const Key('note_row_a')), matching: find.text('Garden')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a note without a title block is listed under its first eight words', (tester) async {
      await pumpScreen(tester, [
        _note('a', '#S-01', _at(0), content: 'Remember to call the plumber about the leaking tap tomorrow morning.'),
      ]);
      expect(find.text('Remember to call the plumber about the leaking…'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('tapping a row opens the note in place and reads it; tapping again closes it', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-02', _at(0, 11), unread: true), _note('b', '#S-01', _at(0, 9), unread: true)]);
      final before = tester.getTopLeft(find.byKey(const Key('note_row_b'))).dy;

      await openRow(tester, 'a');
      expect(find.text('I liked the flat.'), findsOneWidget);
      expect(stored('a').isUnread, isFalse, reason: 'opening reads the note');
      expect(stored('b').isUnread, isTrue);
      expect(find.byKey(const Key('unread_dot_a')), findsNothing, reason: 'the dot dissolved');
      expect(tester.getTopLeft(find.byKey(const Key('note_row_b'))).dy, greaterThan(before), reason: 'the list made room');

      await openRow(tester, 'a');
      expect(find.text('I liked the flat.'), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('note_row_b'))).dy, before);
      await unmount(tester);
    });

    testWidgets('several notes can be open at once', (tester) async {
      await pumpScreen(tester, [
        _note('a', '#S-02', _at(0, 11), content: '**A**\n- first body'),
        _note('b', '#S-01', _at(0, 9), content: '**B**\n- second body'),
      ]);

      await openRow(tester, 'a');
      await openRow(tester, 'b');
      expect(find.text('first body'), findsOneWidget);
      expect(find.text('second body'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the bar toggle opens every listed note, then collapses them, without touching the preference',
        (tester) async {
      await pumpScreen(tester, [
        _note('a', '#S-02', _at(0, 11), content: '**A**\n- first body'),
        _note('b', '#S-01', _at(0, 9), content: '**B**\n- second body', folder: 'Garden'),
      ]);

      await tapAndSettle(tester, find.byKey(const Key('synthesis_expand_all_toggle')));
      expect(find.text('first body'), findsOneWidget);
      expect(find.text('second body'), findsOneWidget);
      expect(find.byTooltip('Collapse all'), findsOneWidget);
      expect(container.read(notesViewPrefsProvider).notesOpenByDefault, isFalse);

      await tapAndSettle(tester, find.byKey(const Key('synthesis_expand_all_toggle')));
      expect(find.text('first body'), findsNothing);
      expect(find.text('second body'), findsNothing);
      expect(find.byTooltip('Open all'), findsOneWidget);
      expect(prefsStore.saves, 0, reason: 'nothing was stored');

      // Only the notes of the current list open: with Garden selected, Work stays closed.
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tapAndSettle(tester, find.byKey(const Key('folder_panel_row_Garden')));
      await tapAndSettle(tester, find.byKey(const Key('synthesis_expand_all_toggle')));
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tapAndSettle(tester, find.byKey(const Key('folder_panel_all_notes')));
      expect(find.text('second body'), findsOneWidget);
      expect(find.text('first body'), findsNothing);
      await unmount(tester);
    });

    testWidgets('"Show notes opened": every note starts open, and staying on one for 3 s reads it', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), unread: true)], prefs: openReadPrefs);
      expect(find.text('I liked the flat.'), findsOneWidget);
      expect(find.byTooltip('Collapse all'), findsOneWidget);

      expect(stored('a').isUnread, isTrue);
      await tester.pump(const Duration(milliseconds: 3100));
      expect(stored('a').isUnread, isFalse);
      await unmount(tester);
    });

    testWidgets('a tap on the text of an opened, unread note reads it at once', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), unread: true)], prefs: openReadPrefs);
      expect(stored('a').isUnread, isTrue);

      await tester.tap(find.text('I liked the flat.'));
      await tester.pump();

      expect(stored('a').isUnread, isFalse);
      await unmount(tester);
    });

    testWidgets('a closed unread note is not read by waiting: only opening reads it', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), unread: true)]);

      await tester.pump(const Duration(seconds: 10));
      expect(stored('a').isUnread, isTrue);
      await unmount(tester);
    });

    testWidgets('a note waiting for its rewrite shows the indicator on its row', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), reprocessing: true), _note('b', '#S-02', _at(0, 11))]);

      expect(find.text('Rewriting…'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('note_row_a')), matching: find.text('Rewriting…')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Read mode and Edit mode', () {
    testWidgets('Read mode (the default) shows the note and the thoughts link, none of the edit controls', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openReadPrefs);

      expect(find.byKey(const Key('expand_raw_notes_a')), findsOneWidget);
      for (final key in ['cluster_folder_dropdown_a', 'style_button_a', 'edit_text_button_a', 'merge_button_a', 'delete_cluster_a']) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      await tapAndSettle(tester, find.byKey(const Key('expand_raw_notes_a')));
      expect(find.text('From 2 thoughts'), findsOneWidget);
      expect(find.text('Thought one of a'), findsOneWidget);
      expect(find.text('Move Out'), findsNothing);
      expect(stored('a').isExpanded, isTrue);
      await unmount(tester);
    });

    testWidgets('the Read | Edit switch shows the action row and remembers the mode', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0)), _note('b', '#S-02', _at(0, 11))], prefs: openReadPrefs);
      expect(find.byKey(const Key('style_button_a')), findsNothing);

      await editMode(tester);
      expect(find.byKey(const Key('style_button_a')), findsOneWidget);
      expect(find.byKey(const Key('cluster_folder_dropdown_a')), findsOneWidget);
      expect(find.byKey(const Key('edit_text_button_a')), findsOneWidget);
      expect(find.byKey(const Key('merge_button_a')), findsOneWidget);
      expect(find.byKey(const Key('delete_cluster_a')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.text('Organised')), findsOneWidget);
      expect(prefsStore.stored!.readMode, isFalse);

      await tapAndSettle(tester, find.byKey(const Key('synthesis_mode_read')));
      expect(find.byKey(const Key('style_button_a')), findsNothing);
      expect(prefsStore.stored!.readMode, isTrue);
      await unmount(tester);
    });

    testWidgets('Edit mode: merge is not offered when there is no other note', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openEditPrefs);
      expect(find.byKey(const Key('style_button_a')), findsOneWidget);
      expect(find.byKey(const Key('merge_button_a')), findsNothing);
      await unmount(tester);
    });

    testWidgets('moving a note to a folder from its folder menu reaches SessionActions.moveToFolder', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), folder: 'Work')], prefs: openEditPrefs);
      // User decision 2026-11-28 (point 9, TASK-106 C): the folder menu became a chooser sheet with a
      // search field; the folders offered and the move itself are asserted as before.
      await tester.tap(find.byKey(const Key('cluster_folder_dropdown_a')));
      await tester.pumpAndSettle();
      expect(_offeredFolders(tester), ['Work', 'Garden', 'Journal', 'Uncategorized']);

      await tester.tap(find.byKey(const Key('folder_option_Garden')));
      await tester.pumpAndSettle();

      expect(stored('a').folder, 'Garden');
      await unmount(tester);
    });

    testWidgets('Style opens the style sheet; the choice reaches SessionActions.applyStyle and shows a message',
        (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openEditPrefs);

      await tapAndSettle(tester, find.byKey(const Key('style_button_a')));
      expect(find.text('AI Style Re-Writer'), findsOneWidget);
      await tester.tap(find.text('Key points'));
      await tester.pumpAndSettle();

      expect(stored('a').appliedStyleId, 'bullets');
      expect(stored('a').isReprocessing, isTrue);
      expect(runner.runs, 1);
      expect(find.text('Applying style "Key points" to #S-01...'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.text('Key points')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('a hand-edited note asks before a rewrite: Cancel keeps it, Rewrite goes on to the sheet', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), style: manualStyleId)], prefs: openEditPrefs);

      expect(find.text('Edited by hand. It is not rewritten automatically; new thoughts are added underneath.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('style_button_a')), matching: find.text('Edited by hand')), findsOneWidget);

      await tapAndSettle(tester, find.byKey(const Key('style_button_a')));
      expect(find.text('Rewriting in a style replaces your own edits to this note.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('rewrite_cancel_button')));
      await tester.pumpAndSettle();
      expect(find.text('AI Style Re-Writer'), findsNothing);
      expect(stored('a').appliedStyleId, manualStyleId);
      expect(runner.runs, 0);

      await tapAndSettle(tester, find.byKey(const Key('style_button_a')));
      await tester.tap(find.byKey(const Key('rewrite_confirm_button')));
      await tester.pumpAndSettle();
      expect(find.text('AI Style Re-Writer'), findsOneWidget);
      await tester.tap(find.text('Casual note'));
      await tester.pumpAndSettle();
      expect(stored('a').appliedStyleId, 'casual');
      expect(runner.runs, 1);
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('Edit text: the editor holds the raw Markdown; Save reaches SessionActions.editNoteText', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), unread: false)], prefs: openEditPrefs);

      // User decision 2026-11-28 (TASK-108 A, point 8): a note's text is edited in place, not in a sheet.
      // The keys became note_edit_field / note_edit_save / note_edit_cancel; the assertions are unchanged.
      await tapAndSettle(tester, find.byKey(const Key('edit_text_button_a')));
      expect(tester.widget<TextField>(find.byKey(const Key('note_edit_field'))).controller!.text, '**Flat visit**\n\n- I liked the flat.');

      await tester.enterText(find.byKey(const Key('note_edit_field')), '**My title**\n\nMy own words.');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('note_edit_field')), findsNothing);
      expect(stored('a').synthesizedContent, '**My title**\n\nMy own words.');
      expect(stored('a').isHandEdited, isTrue);
      expect(find.text('My own words.'), findsOneWidget);
      expect(find.byKey(const Key('hand_edited_notice_a')), findsOneWidget);
      expect(find.text('My title'), findsOneWidget, reason: 'the row title follows the edit; the body does not repeat it');
      expect(runner.runs, 0, reason: 'a hand edit starts no run');
      await unmount(tester);
    });

    testWidgets('Edit text: an empty text is refused with "A note cannot be empty." and nothing changes', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openEditPrefs);

      // User decision 2026-11-28 (TASK-108 A): in-place editor; keys renamed, assertions unchanged.
      await tapAndSettle(tester, find.byKey(const Key('edit_text_button_a')));
      await tester.enterText(find.byKey(const Key('note_edit_field')), '  \n ');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();

      expect(find.text('A note cannot be empty.'), findsOneWidget);
      expect(find.byKey(const Key('note_edit_field')), findsOneWidget);
      expect(stored('a').synthesizedContent, '**Flat visit**\n\n- I liked the flat.');
      expect(stored('a').isHandEdited, isFalse);

      await tester.tap(find.byKey(const Key('note_edit_cancel')));
      await tester.pumpAndSettle();
      await unmount(tester);
    });

    testWidgets('Merge opens the merge sheet and merges into the chosen note', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0, 9)), _note('b', '#S-02', _at(0, 11))], prefs: openEditPrefs);

      await tapAndSettle(tester, find.byKey(const Key('merge_button_a')));
      expect(find.text('Merge Session #S-01'), findsOneWidget);
      await tester.tap(find.byKey(const Key('merge_target_b')));
      await tester.pumpAndSettle();

      final remaining = container.read(synthesisRepositoryProvider);
      expect(remaining.map((c) => c.clusterId), ['b']);
      expect(remaining.single.originNotes, hasLength(4));
      expect(find.text('Merged [#S-01] into #S-02'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('Delete removes the note', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0, 9)), _note('b', '#S-02', _at(0, 11))], prefs: openEditPrefs);

      await tapAndSettle(tester, find.byKey(const Key('delete_cluster_a')));
      await tapAndSettle(tester, find.byKey(const Key('confirm_delete_button')));

      expect(container.read(synthesisRepositoryProvider).map((c) => c.clusterId), ['b']);
      expect(find.byKey(const Key('note_row_a')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Delete asks first, naming the note and what happens to its thoughts; Cancel keeps it', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0, 9)), _note('b', '#S-02', _at(0, 11))], prefs: openEditPrefs);

      await tapAndSettle(tester, find.byKey(const Key('delete_cluster_a')));
      expect(find.text('Delete note #S-01 "Flat visit"?'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('confirm_delete_consequence'))).data,
        'Its 2 thoughts stay in Capture and become ready for Synthesis again.',
      );
      expect(find.byKey(const Key('confirm_delete_button')), findsOneWidget, reason: 'one dialog only');
      expect(container.read(synthesisRepositoryProvider), hasLength(2), reason: 'nothing deleted yet');

      await tapAndSettle(tester, find.byKey(const Key('confirm_delete_cancel')));
      expect(find.byKey(const Key('confirm_delete_button')), findsNothing);
      expect(container.read(synthesisRepositoryProvider), hasLength(2));
      expect(find.byKey(const Key('note_row_a')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the thoughts of a note keep Move Out in Edit mode: to another note, or as an independent note',
        (tester) async {
      final a = _note('a', '#S-01', _at(0, 9));
      await pumpScreen(tester, [a, _note('b', '#S-02', _at(0, 11))], prefs: openEditPrefs);

      await tapAndSettle(tester, find.byKey(const Key('expand_raw_notes_a')));
      final firstId = a.originNotes.first.id;
      final secondId = a.originNotes.last.id;
      expect(find.byKey(Key('move_out_note_$firstId')), findsOneWidget);

      await tapAndSettle(tester, find.byKey(Key('move_out_note_$firstId')));
      await tester.tap(find.byKey(const Key('ejection_move_to_another_clubbed_note_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('target_cluster_b')));
      await tester.pumpAndSettle();
      expect(stored('a').originNotes.map((o) => o.id), [secondId]);
      expect(stored('b').originNotes.map((o) => o.id), contains(firstId));
      expect(find.text('Moved [#01] to #S-02'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // One thought left: it cannot be moved out.
      expect(find.byKey(Key('move_out_note_$secondId')), findsNothing);

      // Thoughts of b: make one independent.
      await tapAndSettle(tester, find.byKey(const Key('expand_raw_notes_b')));
      final bFirst = stored('b').originNotes.first.id;
      await tapAndSettle(tester, find.byKey(Key('move_out_note_$bFirst')));
      await tester.tap(find.byKey(const Key('ejection_make_independent_note_button')));
      await tester.pumpAndSettle();
      expect(container.read(synthesisRepositoryProvider), hasLength(3));
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('ticking a checklist item in an opened note reaches setTaskChecked, in either mode', (tester) async {
      await pumpScreen(
        tester,
        [_note('a', '#S-01', _at(0), content: '**Errands**\n\n- [ ] Call the bank.\n- [ ] Buy milk.')],
        prefs: openReadPrefs,
      );

      await tapAndSettle(tester, find.byKey(const Key('note_task_1')));
      expect(stored('a').synthesizedContent, '**Errands**\n\n- [ ] Call the bank.\n- [x] Buy milk.');
      expect(stored('a').isUnread, isFalse);
      expect(stored('a').isReprocessing, isFalse);

      await editMode(tester);
      await tapAndSettle(tester, find.byKey(const Key('note_task_0')));
      expect(stored('a').synthesizedContent, '**Errands**\n\n- [x] Call the bank.\n- [x] Buy milk.');
      await unmount(tester);
    });

    testWidgets('a restyle that failed shows its message in a SnackBar and clears the notice', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))]);

      container.read(restyleNoticeProvider.notifier).publish(
            const RestyleNotice(clusterId: 'a', message: 'Could not rewrite this note as "Journal entry". It is unchanged.'),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Could not rewrite this note as "Journal entry". It is unchanged.'), findsOneWidget);
      expect(container.read(restyleNoticeProvider), isNull);
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });
  });

  group('the folder panel', () {
    final notes = [
      _note('w1', '#S-03', _at(0, 12), folder: 'Work', unread: true),
      _note('w2', '#S-02', _at(0, 11), folder: 'Work'),
      _note('g1', '#S-01', _at(0, 9), folder: 'Garden', unread: true),
      _note('x1', '#S-01', _at(1, 9), folder: 'Ideas'),
    ];

    testWidgets('opens only by tapping the folder button, not by swiping', (tester) async {
      await pumpScreen(tester, notes);
      expect(find.byKey(const Key('folder_panel')), findsNothing);

      await tester.dragFrom(const Offset(3, 400), const Offset(250, 0));
      await tester.pumpAndSettle();
      await tester.fling(find.byKey(const Key('note_row_w1')), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_panel')), findsNothing, reason: 'horizontal swipes belong to the tab switch');

      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      expect(find.byKey(const Key('folder_panel')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('folder_panel'))).width, closeTo(288, 0.5));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('shows All notes and every folder with note counts and unread badges, and folders that left the list',
        (tester) async {
      await pumpScreen(tester, notes);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));

      String countOf(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
      String unreadOf(String key) => tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).data!;
      expect(countOf('folder_panel_all_notes_count'), '4');
      expect(unreadOf('folder_panel_all_notes_unread'), '2');
      expect(countOf('folder_panel_row_Work_count'), '2');
      expect(unreadOf('folder_panel_row_Work_unread'), '1');
      expect(countOf('folder_panel_row_Garden_count'), '1');
      expect(countOf('folder_panel_row_Journal_count'), '0');
      expect(find.byKey(const Key('folder_panel_row_Journal_unread')), findsNothing);
      expect(find.byKey(const Key('folder_panel_row_Ideas')), findsOneWidget, reason: 'not in the list, still holds a note');
      expect(find.text('Manage folders'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('choosing a folder filters the list and closes the panel; All notes brings everything back',
        (tester) async {
      await pumpScreen(tester, notes);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tester.tap(find.byKey(const Key('folder_panel_row_Work')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('folder_panel')), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('synthesis_folder_button')), matching: find.text('Work')), findsOneWidget);
      expect(find.byKey(const Key('note_row_w1')), findsOneWidget);
      expect(find.byKey(const Key('note_row_w2')), findsOneWidget);
      expect(find.byKey(const Key('note_row_g1')), findsNothing);

      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tester.tap(find.byKey(const Key('folder_panel_all_notes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_row_g1')), findsOneWidget);
      expect(find.text('All notes'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the triage chips filter, the folder button shows a badge while one is on, and the panel stays open',
        (tester) async {
      await pumpScreen(tester, notes);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));

      await tester.tap(find.byKey(const Key('triage_chip_unread')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_panel')), findsOneWidget);
      expect(find.byKey(const Key('synthesis_filter_badge')), findsOneWidget);
      expect(find.byKey(const Key('note_row_w1')), findsOneWidget);
      expect(find.byKey(const Key('note_row_w2')), findsNothing);
      expect(find.byKey(const Key('note_row_g1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('triage_chip_read')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_row_w1')), findsNothing);
      expect(find.byKey(const Key('note_row_w2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('triage_chip_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('synthesis_filter_badge')), findsNothing);
      expect(find.byKey(const Key('note_row_w1')), findsOneWidget);
      await unmount(tester);
    });

    group('the Unread and Read filters keep what they listed', () {
      Future<void> pickFilter(WidgetTester tester, String chip) async {
        await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
        await tester.tap(find.byKey(Key('triage_chip_$chip')));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(350, 500)); // the scrim closes the panel
        await tester.pumpAndSettle();
      }

      testWidgets('opening a note under Unread reads it, and it stays listed and open', (tester) async {
        await pumpScreen(tester, notes);
        await pickFilter(tester, 'unread');
        expect(find.byKey(const Key('note_row_w2')), findsNothing);

        await openRow(tester, 'w1');

        expect(stored('w1').isUnread, isFalse);
        expect(find.byKey(const Key('note_row_w1')), findsOneWidget, reason: 'it did not vanish');
        expect(find.text('I liked the flat.'), findsOneWidget, reason: 'and it opened');
        expect(find.byKey(const Key('unread_dot_w1')), findsNothing, reason: 'its dot dissolved');
        expect(find.byKey(const Key('note_row_w2')), findsNothing, reason: 'a read note was never listed under Unread');
        await unmount(tester);
      });

      testWidgets('the panel keeps showing the true counts while a read note stays listed', (tester) async {
        await pumpScreen(tester, notes);
        await pickFilter(tester, 'unread');
        await openRow(tester, 'w1');

        await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
        expect(tester.widget<Text>(find.byKey(const Key('folder_panel_all_notes_count'))).data, '4');
        expect(
          tester.widget<Text>(find.descendant(
              of: find.byKey(const Key('folder_panel_all_notes_unread')), matching: find.byType(Text))).data,
          '1',
          reason: 'w1 was read: one unread note is left, though w1 is still listed',
        );
        await unmount(tester);
      });

      testWidgets('picking a chip (even the same one) drops what was kept; new matches still appear', (tester) async {
        await pumpScreen(tester, notes);
        await pickFilter(tester, 'unread');
        await openRow(tester, 'w1');
        expect(find.byKey(const Key('note_row_w1')), findsOneWidget);

        await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
        await tester.tap(find.byKey(const Key('triage_chip_unread')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('note_row_w1')), findsNothing, reason: 'the same chip again refreshes the list');
        expect(find.byKey(const Key('note_row_g1')), findsOneWidget);

        // A note read while it is listed stays.
        container.read(synthesisRepositoryProvider.notifier).markClusterAsRead('g1');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('note_row_g1')), findsOneWidget, reason: 'kept after being read');
        await unmount(tester);
      });

      testWidgets('changing folder drops what was kept', (tester) async {
        await pumpScreen(tester, notes);
        await pickFilter(tester, 'unread');
        await openRow(tester, 'w1');

        await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
        await tapAndSettle(tester, find.byKey(const Key('folder_panel_row_Garden')));
        await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
        await tapAndSettle(tester, find.byKey(const Key('folder_panel_all_notes')));

        expect(find.byKey(const Key('note_row_w1')), findsNothing);
        expect(find.byKey(const Key('note_row_g1')), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('under Read a note that turns out unread is not listed, and one read meanwhile stays', (tester) async {
        await pumpScreen(tester, notes);
        await pickFilter(tester, 'read');
        expect(find.byKey(const Key('note_row_w2')), findsOneWidget);
        expect(find.byKey(const Key('note_row_w1')), findsNothing);

        container.read(synthesisRepositoryProvider.notifier).markClusterAsRead('w1');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('note_row_w1')), findsOneWidget, reason: 'new matches appear');
        await unmount(tester);
      });
    });

    testWidgets('the scrim and the back button close it', (tester) async {
      await pumpScreen(tester, notes);

      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tester.tapAt(const Offset(345, 600));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_panel')), findsNothing);

      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      expect(find.byKey(const Key('folder_panel')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_panel')), findsNothing);
      expect(find.byType(SynthesisScreen), findsOneWidget, reason: 'back closed the panel, nothing else');
      await unmount(tester);
    });

    testWidgets('Manage folders opens Settings', (tester) async {
      await pumpScreen(tester, notes);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));

      await tester.tap(find.byKey(const Key('manage_folders_link')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('NOTES'), findsOneWidget, reason: 'the new section is part of Settings');
      await tester.tap(find.byKey(const Key('settings_back_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_panel')), findsNothing, reason: 'the panel closed on its way to Settings');
      await unmount(tester);
    });

    testWidgets('a selected folder that no longer exists and holds no notes no longer filters', (tester) async {
      await pumpScreen(tester, [_note('g1', '#S-01', _at(0), folder: 'Garden')]);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tapAndSettle(tester, find.byKey(const Key('folder_panel_row_Garden')));

      container.read(synthesisRepositoryProvider.notifier).moveFolderSessions('Garden', 'Work');
      await tester.pumpAndSettle();
      await container.read(foldersProvider.notifier).remove('Garden');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('note_row_g1')), findsOneWidget);
      expect(find.text('All notes'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('choosers, the new-folder button and the Copy control (TASK-106, user decisions 2026-11-28)', () {
    final notes = [
      _note('a', '#S-03', _at(0, 12), folder: 'Work', content: '**Flat visit**\n- I liked the flat.'),
      _note('b', '#S-02', _at(0, 11), folder: 'Garden', content: '**Tomato beds**\n- Water the tomatoes.'),
      _note('c', '#S-01', _at(0, 10), folder: 'Journal', content: '**Quiet evening**\n- Slept early and read.'),
    ];

    Finder folderOption(String name) => find.byKey(Key('folder_option_$name'));

    testWidgets('the + beside Manage folders opens the same new-folder editor as Settings and saves a folder',
        (tester) async {
      await pumpScreen(tester, notes);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));

      expect(find.byKey(const Key('manage_folders_link')), findsOneWidget);
      expect(find.byTooltip('New folder'), findsOneWidget);
      await tester.tap(find.byKey(const Key('folder_panel_add')));
      await tester.pumpAndSettle();

      expect(find.text('New folder'), findsWidgets);
      expect(find.byKey(const Key('folder_name_field')), findsOneWidget);
      expect(find.byKey(const Key('folder_delete_button')), findsNothing, reason: 'a new folder, not an edit');
      await tester.enterText(find.byKey(const Key('folder_name_field')), 'Reading');
      await tester.tap(find.byKey(const Key('folder_save_button')));
      await tester.pumpAndSettle();

      expect([for (final f in container.read(foldersProvider)) f.name], contains('Reading'));
      expect(find.byKey(const Key('folder_panel_row_Reading')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the folder chooser filters by folder name only, ignoring case; a description word does not match',
        (tester) async {
      await pumpScreen(tester, notes, prefs: openEditPrefs, height: 800);
      await tapAndSettle(tester, find.byKey(const Key('cluster_folder_dropdown_a')));

      expect(find.byKey(const Key('folder_search_field')), findsOneWidget);
      expect(find.text('Search folders'), findsOneWidget);
      expect(_offeredFolders(tester), ['Work', 'Garden', 'Journal', 'Uncategorized']);

      await tester.enterText(find.byKey(const Key('folder_search_field')), 'GARD');
      await tester.pump();
      expect(_offeredFolders(tester), ['Garden']);

      // 'plants' is in Garden's description only.
      await tester.enterText(find.byKey(const Key('folder_search_field')), 'plants');
      await tester.pump();
      expect(_offeredFolders(tester), isEmpty);
      expect(find.text('No folder matches'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('folder_search_field')), 'ar');
      await tester.pump();
      await tester.tap(folderOption('Garden'));
      await tester.pumpAndSettle();
      expect(stored('a').folder, 'Garden');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('the folder chooser fits a 360x800 phone, also with the keyboard up', (tester) async {
      await pumpScreen(tester, notes, prefs: openEditPrefs, height: 800);
      await tapAndSettle(tester, find.byKey(const Key('cluster_folder_dropdown_a')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byKey(const Key('folder_search_field')));
      expect(sheet.left, greaterThanOrEqualTo(0));
      expect(sheet.right, lessThanOrEqualTo(360));
      expect(sheet.bottom, lessThanOrEqualTo(800 - 300), reason: 'the search field stays above the keyboard');
      await unmount(tester);
    });

    testWidgets('the merge chooser filters the candidates by title and by text, ignoring case', (tester) async {
      await pumpScreen(tester, notes, prefs: openEditPrefs, height: 800);
      await tapAndSettle(tester, find.byKey(const Key('merge_button_a')));

      expect(find.byKey(const Key('merge_search_field')), findsOneWidget);
      expect(find.text('Search notes'), findsOneWidget);
      expect(find.byKey(const Key('merge_target_b')), findsOneWidget);
      expect(find.byKey(const Key('merge_target_c')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('merge_search_field')), 'TOMATO BEDS'); // title
      await tester.pump();
      expect(find.byKey(const Key('merge_target_b')), findsOneWidget);
      expect(find.byKey(const Key('merge_target_c')), findsNothing);

      await tester.enterText(find.byKey(const Key('merge_search_field')), 'slept early'); // body text
      await tester.pump();
      expect(find.byKey(const Key('merge_target_b')), findsNothing);
      expect(find.byKey(const Key('merge_target_c')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('merge_search_field')), 'zebra');
      await tester.pump();
      expect(find.text('No note matches'), findsOneWidget);
      expect(find.byKey(const Key('merge_target_c')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('the merge chooser fits a 360x800 phone and still merges into the filtered note', (tester) async {
      await pumpScreen(tester, notes, prefs: openEditPrefs, height: 800);
      await tapAndSettle(tester, find.byKey(const Key('merge_button_a')));
      await tester.enterText(find.byKey(const Key('merge_search_field')), 'tomatoes');
      await tester.pump();

      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byKey(const Key('merge_search_field')));
      expect(field.left, greaterThanOrEqualTo(0));
      expect(field.right, lessThanOrEqualTo(360));
      await tester.tap(find.byKey(const Key('merge_target_b')));
      await tester.pumpAndSettle();
      expect(container.read(synthesisRepositoryProvider).any((c) => c.clusterId == 'a'), isFalse, reason: 'merged away');
      await unmount(tester);
    });

    testWidgets('Read mode: the note text has the full width and Copy sits at the right end of the thoughts row',
        (tester) async {
      await pumpScreen(tester, [notes.first], prefs: openReadPrefs, height: 800);

      final body = tester.getRect(find.byType(NoteBody));
      final text = tester.getRect(find.byType(NoteMarkdownView));
      expect(text.width, body.width, reason: 'the copy button no longer takes a column beside the text');
      final copy = tester.getRect(find.byKey(const Key('note_copy_button')));
      final thoughts = tester.getRect(find.byKey(const Key('expand_raw_notes_a')));
      expect(copy.right, body.right);
      // (The test font is wide, so the row's date may wrap below the link: overlap is what counts.)
      expect(copy.top, lessThan(thoughts.bottom), reason: 'same row as From N thoughts');
      expect(copy.bottom, greaterThan(thoughts.top), reason: 'same row as From N thoughts');
      expect(copy.top, greaterThan(text.bottom - 1), reason: 'under the text, not beside it');
      expect(find.byKey(const Key('note_copy_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Edit mode: one Copy control, in the action row, and the note text has the full width',
        (tester) async {
      await pumpScreen(tester, [notes.first], prefs: openEditPrefs, height: 800);

      expect(find.byKey(const Key('note_copy_button')), findsOneWidget);
      expect(
        find.descendant(of: find.byType(NoteActionRow), matching: find.byKey(const Key('note_copy_button'))),
        findsOneWidget,
      );
      expect(tester.getRect(find.byType(NoteMarkdownView)).width, tester.getRect(find.byType(NoteBody)).width);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('a request from Capture to show a note', () {
    testWidgets('selects All notes, clears a triage filter that hides it, opens its row and highlights it', (tester) async {
      await pumpScreen(tester, [
        _note('a', '#S-02', _at(0, 11), folder: 'Work', unread: true, content: '**Alpha**\n- alpha body'),
        _note('b', '#S-01', _at(0, 9), folder: 'Garden', content: '**Beta**\n- beta body'),
      ]);
      await tapAndSettle(tester, find.byKey(const Key('synthesis_folder_button')));
      await tester.tap(find.byKey(const Key('triage_chip_unread')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('folder_panel_row_Work')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_row_b')), findsNothing);

      container.read(synthesisFocusRequestProvider.notifier).request('b');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(synthesisFocusRequestProvider), isNull);
      expect(find.byKey(const Key('note_row_b')), findsOneWidget);
      expect(find.text('All notes'), findsOneWidget);
      expect(find.byKey(const Key('synthesis_filter_badge')), findsNothing);
      expect(find.text('beta body'), findsOneWidget, reason: 'its row is open');
      expect(find.text('alpha body'), findsNothing);
      final glow = (tester.widget<AnimatedContainer>(find.byKey(sessionCardKey('b'))).decoration! as BoxDecoration).boxShadow;
      expect(glow, isNotEmpty);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('scrolls a note far down the list into view', (tester) async {
      await pumpScreen(
        tester,
        [for (var i = 1; i <= 30; i++) _note('c$i', '#S-${i.toString().padLeft(2, '0')}', _at(0, 8))],
        height: 800,
      );
      expect(find.byKey(const Key('note_row_c1')), findsNothing);

      container.read(synthesisFocusRequestProvider.notifier).request('c1');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('note_row_c1')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(sessionCardKey('c1'))).dy, inInclusiveRange(0, 700));
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });
  });

  // User decisions 2026-11-28 (TASK-108): a note's text is edited where it stands (A, point 8) and
  // a raw thought opens in Capture when tapped (B, point 14).
  group('editing a note in place (TASK-108 A) and opening a thought in Capture (TASK-108 B)', () {
    const original = '**Flat visit**\n\n- I liked the flat.';

    Finder field() => find.byKey(const Key('note_edit_field'));
    Finder textOf(String id) => find.byKey(Key('note_text_tap_$id'));

    testWidgets('Read mode: a tap on the text turns it into the editor; Save stores through editNoteText', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openReadPrefs, height: 800);
      expect(field(), findsNothing);

      await tapAndSettle(tester, textOf('a'));
      expect(field(), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, original);
      final editable = tester.widget<EditableText>(find.descendant(of: field(), matching: find.byType(EditableText)));
      expect(editable.focusNode.hasFocus, isTrue, reason: 'focused at once');
      expect(find.byKey(const Key('note_edit_save')), findsOneWidget);
      expect(find.byKey(const Key('note_edit_cancel')), findsOneWidget);
      expect(find.byKey(const Key('edit_text_button_a')), findsNothing, reason: 'Read mode has no action row');

      await tester.enterText(field(), '**My title**\n\nMy own words.');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();

      expect(field(), findsNothing);
      expect(stored('a').synthesizedContent, '**My title**\n\nMy own words.');
      expect(stored('a').appliedStyleId, manualStyleId);
      expect(stored('a').isHandEdited, isTrue, reason: 'FR11.19');
      expect(find.text('My own words.'), findsOneWidget);
      expect(runner.runs, 0, reason: 'a hand edit starts no run');
      await unmount(tester);
    });

    testWidgets('Edit mode: a tap on the text and Edit text both open the same editor', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openEditPrefs, height: 800);

      await tapAndSettle(tester, textOf('a'));
      expect(field(), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, original);
      await tapAndSettle(tester, find.byKey(const Key('note_edit_cancel')));
      expect(field(), findsNothing);

      await tapAndSettle(tester, find.byKey(const Key('edit_text_button_a')));
      expect(field(), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, original);
      await unmount(tester);
    });

    testWidgets('Save with the text unchanged closes the editor and changes nothing (not hand-edited)', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), unread: false)], prefs: openReadPrefs, height: 800);

      await tapAndSettle(tester, textOf('a'));
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();

      expect(field(), findsNothing);
      expect(stored('a').synthesizedContent, original);
      expect(stored('a').appliedStyleId, defaultNoteStyleId);
      expect(stored('a').isHandEdited, isFalse);
      expect(runner.runs, 0);

      // Only trailing whitespace added: still unchanged.
      await tapAndSettle(tester, textOf('a'));
      await tester.enterText(field(), '$original\n\n');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();
      expect(stored('a').isHandEdited, isFalse);
      await unmount(tester);
    });

    testWidgets('Cancel discards what was typed and changes nothing', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openReadPrefs, height: 800);

      await tapAndSettle(tester, textOf('a'));
      await tester.enterText(field(), 'something else');
      await tester.tap(find.byKey(const Key('note_edit_cancel')));
      await tester.pumpAndSettle();

      expect(field(), findsNothing);
      expect(stored('a').synthesizedContent, original);
      expect(stored('a').isHandEdited, isFalse);
      expect(find.text('I liked the flat.'), findsOneWidget);
      await tapAndSettle(tester, textOf('a'));
      expect(tester.widget<TextField>(field()).controller!.text, original, reason: 'a new editing starts from the note');
      await unmount(tester);
    });

    testWidgets('an empty text is refused with "A note cannot be empty." and the editor stays', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openReadPrefs, height: 800);

      await tapAndSettle(tester, textOf('a'));
      await tester.enterText(field(), ' \n ');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();

      expect(find.text('A note cannot be empty.'), findsOneWidget);
      expect(field(), findsOneWidget);
      expect(stored('a').synthesizedContent, original);
      await unmount(tester);
    });

    testWidgets('ticking a checklist box ticks the task and does not start editing', (tester) async {
      await pumpScreen(
        tester,
        [_note('a', '#S-01', _at(0), content: '**Plan**\n\n- [ ] Buy milk\n- [ ] Call mum')],
        prefs: openReadPrefs,
        height: 800,
      );

      await tapAndSettle(tester, find.byKey(const Key('note_task_box_0')));

      expect(field(), findsNothing);
      expect(stored('a').synthesizedContent, contains('- [x] Buy milk'));
      expect(stored('a').synthesizedContent, contains('- [ ] Call mum'));
      expect(stored('a').isHandEdited, isFalse);
      await unmount(tester);
    });

    testWidgets('a note being rewritten can be edited by a tap on its text or Edit text; Save stores it, marks it hand-edited and clears the rewrite',
        (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0), reprocessing: true)], prefs: openReadPrefs, height: 800);
      expect(stored('a').isReprocessing, isTrue);

      await tapAndSettle(tester, textOf('a'));
      expect(field(), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const Key('note_edit_cancel')));
      expect(field(), findsNothing);

      await editMode(tester);
      await tapAndSettle(tester, find.byKey(const Key('edit_text_button_a')));
      expect(field(), findsOneWidget);
      await tester.enterText(field(), '**Mine**\n\nMy own words.');
      await tester.tap(find.byKey(const Key('note_edit_save')));
      await tester.pumpAndSettle();

      expect(field(), findsNothing);
      expect(stored('a').synthesizedContent, '**Mine**\n\nMy own words.');
      expect(stored('a').appliedStyleId, manualStyleId);
      expect(stored('a').isHandEdited, isTrue, reason: 'FR11.19');
      expect(stored('a').isReprocessing, isFalse, reason: 'the hand edit wins over the pending rewrite');
      expect(runner.runs, 0);
      await unmount(tester);
    });

    testWidgets('one note is edited at a time: a second note is refused, the first keeps its typing', (tester) async {
      await pumpScreen(
        tester,
        [_note('a', '#S-02', _at(0, 11)), _note('b', '#S-01', _at(0, 9), content: '**Other**\n\n- other body')],
        prefs: openReadPrefs,
        height: 1400,
      );

      await tapAndSettle(tester, textOf('a'));
      await tester.enterText(field(), 'half typed');
      await tapAndSettle(tester, textOf('b'));

      expect(find.text(finishEditingFirstNotice), findsOneWidget);
      expect(field(), findsOneWidget);
      expect(tester.widget<TextField>(field()).controller!.text, 'half typed');
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('the typing survives the note being closed and opened again', (tester) async {
      await pumpScreen(tester, [_note('a', '#S-01', _at(0))], prefs: openReadPrefs, height: 800);

      await tapAndSettle(tester, textOf('a'));
      await tester.enterText(field(), 'half typed');
      await tapAndSettle(tester, find.byKey(const Key('note_row_a')));
      expect(field(), findsNothing, reason: 'closed note shows no body');
      await tapAndSettle(tester, find.byKey(const Key('note_row_a')));

      expect(tester.widget<TextField>(field()).controller!.text, 'half typed');
      await unmount(tester);
    });

    testWidgets('on a 360x800 phone with the keyboard up the editor, Cancel and Save stay on screen', (tester) async {
      await pumpScreen(
        tester,
        [for (var i = 1; i <= 6; i++) _note('n$i', '#S-0$i', _at(0, 20 - i), content: '**Note $i**\n\n- body $i')],
        prefs: openReadPrefs,
        height: 800,
      );
      await tapAndSettle(tester, textOf('n4'));
      // The keyboard comes up after the editor opened, as it does on a phone.
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final key in ['note_edit_field', 'note_edit_cancel', 'note_edit_save']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(360), reason: key);
        expect(rect.top, greaterThanOrEqualTo(0), reason: key);
        expect(rect.bottom, lessThanOrEqualTo(800 - 320), reason: '$key stays above the keyboard');
      }
      await unmount(tester);
    });

    testWidgets('tapping a thought asks Capture to show it by its id; Move Out in Edit mode keeps working',
        (tester) async {
      final a = _note('a', '#S-01', _at(0, 9));
      await pumpScreen(tester, [a, _note('b', '#S-02', _at(0, 11))], prefs: openEditPrefs);
      await tapAndSettle(tester, find.byKey(const Key('expand_raw_notes_a')));
      final firstId = a.originNotes.first.id;
      final secondId = a.originNotes.last.id;
      expect(container.read(captureFocusRequestProvider), isNull);
      expect(find.byTooltip('Open in Capture'), findsNWidgets(2));

      await tapAndSettle(tester, find.byKey(Key('raw_thought_open_$secondId')));
      expect(container.read(captureFocusRequestProvider), secondId);
      container.read(captureFocusRequestProvider.notifier).clear();

      await tapAndSettle(tester, find.text('Thought one of a'));
      expect(container.read(captureFocusRequestProvider), firstId, reason: 'the whole row is the target');
      container.read(captureFocusRequestProvider.notifier).clear();

      await tapAndSettle(tester, find.byKey(Key('move_out_note_$firstId')));
      expect(container.read(captureFocusRequestProvider), isNull, reason: 'Move Out is its own button');
      await tester.tap(find.byKey(const Key('ejection_move_to_another_clubbed_note_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('target_cluster_b')));
      await tester.pumpAndSettle();
      expect(stored('b').originNotes.map((o) => o.id), contains(firstId));
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('in Read mode a thought also opens in Capture', (tester) async {
      final a = _note('a', '#S-01', _at(0, 9));
      await pumpScreen(tester, [a], prefs: openReadPrefs);
      await tapAndSettle(tester, find.byKey(const Key('expand_raw_notes_a')));

      await tapAndSettle(tester, find.byKey(Key('raw_thought_open_${a.originNotes.first.id}')));
      expect(container.read(captureFocusRequestProvider), a.originNotes.first.id);
      await unmount(tester);
    });
  });
}

class _FixedTab extends SelectedShellTabNotifier {
  final ShellTab initial;
  _FixedTab(this.initial);

  @override
  ShellTab? build() => initial;
}

/// The folders a note's folder chooser offers, in order.
List<String> _offeredFolders(WidgetTester tester) => [
      for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('folder_option_')).evaluate())
        (e.widget.key as ValueKey<String>).value.substring('folder_option_'.length),
    ];
