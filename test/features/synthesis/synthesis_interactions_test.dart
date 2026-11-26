import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

import 'notes_view_test_support.dart';

/// A runner the test steers: it either never starts (returns [earlyResult]) or starts and ends on demand.
class _ControlledRunner implements SynthesisRunner {
  final Ref ref;
  final Completer<SynthesisRunResult> finish = Completer();
  final bool startsRunning;
  int runs = 0;

  _ControlledRunner(this.ref, {required this.startsRunning});

  @override
  Future<SynthesisRunResult> run({required bool manual}) {
    runs++;
    if (startsRunning) {
      ref.read(synthesisRunningProvider.notifier).setRunning(true);
      finish.future.whenComplete(() => ref.read(synthesisRunningProvider.notifier).setRunning(false));
    }
    return finish.future;
  }

  @override
  bool get isRunning => startsRunning && !finish.isCompleted;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

DateTime _at(int daysAgo, [int hour = 10]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - daysAgo, hour);
}

SynthesisCluster _session(
  String id,
  String label,
  DateTime start, {
  bool unread = false,
  bool reprocessing = false,
  String folder = 'Work',
  String? content,
  List<SynthesisOriginNote> origins = const [],
}) =>
    SynthesisCluster(
      clusterId: id,
      sequenceNumber: label,
      folder: folder,
      synthesizedContent: content ?? 'Note of $id',
      sessionStart: start,
      sessionEnd: start,
      sessionDuration: Duration.zero,
      originNotes: origins,
      isUnread: unread,
      isReprocessing: reprocessing,
    );

String _dayMonth(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

void main() {
  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester,
    List<SynthesisCluster> clusters, {
    bool startsRunning = true,
    ShellTab? shellTab,
    NotesRepository? notes,
    double height = 800,
    NotesViewPrefs prefs = const NotesViewPrefs(),
  }) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(notes ?? NotesRepository()),
          notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore(prefs)),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
          activeSynthesisProfileProvider.overrideWithValue(ModelCatalogue.qwen3_4b.profile!),
          synthesisRunnerProvider.overrideWith((ref) => _ControlledRunner(ref, startsRunning: startsRunning)),
          if (shellTab != null) selectedShellTabProvider.overrideWith(() => _FixedTab(shellTab)),
        ],
        child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(SynthesisScreen)));
    await tester.pump();
    await tester.pump(); // the stored view preferences arrive
  }

  Finder card(String id) => find.byKey(sessionCardKey(id));

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  group('A synthesis run is visible (FR11.16)', () {
    Future<NotesRepository> withWaitingThought() async {
      final notes = NotesRepository();
      await notes.saveNote(Note(correctedText: 'A thought waiting', state: ThoughtState.processed));
      return notes;
    }

    testWidgets('tapping Synthesize Now shows the run at once, keeps it for the whole run, then returns',
        (tester) async {
      final notes = await withWaitingThought();
      await pumpScreen(tester, [_session('c1', '#S-01', _at(0))], notes: notes);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      final button = find.byKey(const Key('synthesize_now_banner_button'));
      expect(button, findsOneWidget);
      expect(find.text('Synthesize Now'), findsOneWidget);
      final idleSize = tester.getSize(button);
      InkWell inkWell() => tester.widget<InkWell>(find.descendant(of: button, matching: find.byType(InkWell)));
      expect(inkWell().onTap, isNotNull);

      await tester.tap(button);
      await tester.pump(); // one frame: the runner has not answered anything yet

      expect(find.text('Synthesizing…'), findsOneWidget);
      expect(find.text('Synthesize Now'), findsNothing);
      expect(inkWell().onTap, isNull, reason: 'unclickable while the run is on');
      expect(tester.getSize(button), idleSize, reason: 'no layout jump');
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // A second tap does nothing.
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect((container.read(synthesisRunnerProvider) as _ControlledRunner).runs, 1);

      // The run holds the model: the state is the runner's own now.
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(synthesisRunningProvider), isTrue);
      expect(find.text('Synthesizing…'), findsOneWidget);

      (container.read(synthesisRunnerProvider) as _ControlledRunner).finish.complete(SynthesisRunResult.completed);
      await tester.pump();
      await tester.pump();
      expect(find.text('Synthesizing…'), findsNothing);
      expect(find.text('Synthesize Now'), findsOneWidget);
      expect(inkWell().onTap, isNotNull);
      await unmount(tester);
    });

    testWidgets('a run that does not start shows the message and the button comes back', (tester) async {
      final notes = await withWaitingThought();
      await pumpScreen(tester, [_session('c1', '#S-01', _at(0))], startsRunning: false, notes: notes);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('synthesize_now_banner_button')));
      await tester.pump();
      expect(find.text('Synthesizing…'), findsOneWidget, reason: 'shown before the runner has answered');

      (container.read(synthesisRunnerProvider) as _ControlledRunner).finish.complete(SynthesisRunResult.busy);
      await tester.pump();
      await tester.pump();

      expect(find.text('Capture is busy. Try again in a moment.'), findsOneWidget);
      expect(find.text('Synthesizing…'), findsNothing);
      expect(find.text('Synthesize Now'), findsOneWidget);
      expect(container.read(synthesisRunningProvider), isFalse);
      await unmount(tester);
    });

    testWidgets('a session waiting for its rewrite shows "Rewriting…" in its row, in place of the time', (tester) async {
      await pumpScreen(tester, [
        _session('c1', '#S-01', _at(0), reprocessing: true),
        _session('c2', '#S-02', _at(0)),
      ]);

      expect(find.text('Rewriting…'), findsOneWidget);
      expect(find.descendant(of: card('c1'), matching: find.byType(ThinkingIndicator)), findsOneWidget);
      expect(find.descendant(of: card('c2'), matching: find.byType(ThinkingIndicator)), findsNothing);
      expect(find.descendant(of: card('c1'), matching: find.text('10:00 AM')), findsNothing);
      expect(find.descendant(of: card('c2'), matching: find.text('10:00 AM')), findsOneWidget);
      // Still while no run is going; it moves once one is.
      expect(tester.hasRunningAnimations, isFalse);

      container.read(synthesisRunningProvider.notifier).setRunning(true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      container.read(synthesisRunningProvider.notifier).setRunning(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Sessions are listed by day, newest first (FR11.4)', () {
    testWidgets('day headers like Capture, newest day first, numbers descending inside a day, keys by id',
        (tester) async {
      await pumpScreen(tester, height: 1600, [
        _session('old', '#S-01', _at(3)),
        _session('y1', '#S-01', _at(1)),
        _session('t1', '#S-01', _at(0, 8)),
        _session('t2', '#S-02', _at(0, 9)),
      ]);

      expect(find.text('TODAY — ${_dayMonth(_at(0))}'), findsOneWidget);
      expect(find.text('YESTERDAY — ${_dayMonth(_at(1))}'), findsOneWidget);
      expect(find.text(_dayMonth(_at(3))), findsOneWidget);

      double top(Finder f) => tester.getTopLeft(f).dy;
      final today = top(find.text('TODAY — ${_dayMonth(_at(0))}'));
      final yesterday = top(find.text('YESTERDAY — ${_dayMonth(_at(1))}'));
      final older = top(find.text(_dayMonth(_at(3))));
      expect(today, lessThan(top(card('t2'))));
      expect(top(card('t2')), lessThan(top(card('t1'))), reason: '#S-02 above #S-01 of the same day');
      expect(top(card('t1')), lessThan(yesterday));
      expect(yesterday, lessThan(top(card('y1'))));
      expect(top(card('y1')), lessThan(older));
      expect(older, lessThan(top(card('old'))));

      // Three sessions are called #S-01; every one is its own row.
      expect(find.text('#S-01'), findsNWidgets(3));
      expect(find.byKey(const Key('note_row_y1')), findsOneWidget);
      expect(find.byKey(const Key('note_row_t1')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the merge sheet names the day of a target from another day', (tester) async {
      await pumpScreen(tester, prefs: openEditPrefs, height: 1600, [
        _session('t1', '#S-01', _at(0)),
        _session('y1', '#S-01', _at(1)),
        _session('t2', '#S-02', _at(0, 11)),
      ]);
      await tester.pumpAndSettle(); // the notes finish opening

      await tester.tap(find.byKey(const Key('merge_button_t1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merge_target_y1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('merge_target_y1')), matching: find.text('#S-01 · ${_dayMonth(_at(1))}')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('merge_target_t2')), matching: find.text('#S-02')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the move-out sheet names the day of a target from another day', (tester) async {
      final origins = [
        SynthesisOriginNote(id: 1, formattedSequence: '#01', cleanedText: 'First', timestamp: _at(0)),
        SynthesisOriginNote(id: 2, formattedSequence: '#02', cleanedText: 'Second', timestamp: _at(0)),
      ];
      await pumpScreen(tester, prefs: openEditPrefs, height: 1600, [
        _session('t1', '#S-01', _at(0), origins: origins),
        _session('y1', '#S-01', _at(1)),
      ]);
      await tester.pumpAndSettle(); // the notes finish opening

      await tester.tap(find.byKey(const Key('expand_raw_notes_t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('move_out_note_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ejection_move_to_another_clubbed_note_button')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('target_cluster_y1')), matching: find.text('#S-01 · ${_dayMonth(_at(1))}')),
          findsOneWidget);
      await unmount(tester);
    });
  });

  group('A session is read when it has been seen (FR11.10)', () {
    testWidgets('tapping a card marks it read: the dot dissolves, the card keeps its place', (tester) async {
      await pumpScreen(tester, [
        _session('a', '#S-02', _at(0, 11), unread: true, content: 'Alpha text'),
        _session('b', '#S-01', _at(0, 9), unread: true, content: 'Beta text'),
      ]);
      final before = tester.getTopLeft(card('a'));
      expect(find.byKey(const Key('unread_dot_a')), findsOneWidget);

      await tester.tap(find.text('Alpha text'));
      await tester.pump();

      expect(container.read(synthesisRepositoryProvider).firstWhere((c) => c.clusterId == 'a').isUnread, isFalse);
      expect(container.read(synthesisRepositoryProvider).firstWhere((c) => c.clusterId == 'b').isUnread, isTrue);
      expect(find.byKey(const Key('unread_dot_a')), findsOneWidget, reason: 'dissolving');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const Key('unread_dot_a')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('unread_dot_a')), findsNothing);
      expect(find.byKey(const Key('unread_dot_b')), findsOneWidget);
      expect(tester.getTopLeft(card('a')), before);
      await unmount(tester);
    });

    testWidgets('staying on a card for 3 seconds marks it read', (tester) async {
      await pumpScreen(tester, prefs: openReadPrefs, [_session('a', '#S-01', _at(0), unread: true)]);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(container.read(synthesisRepositoryProvider).single.isUnread, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(synthesisRepositoryProvider).single.isUnread, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('unread_dot_a')), findsNothing);
      await unmount(tester);
    });

    testWidgets('a card below the fold is not read until it is scrolled into view for 3 seconds', (tester) async {
      await pumpScreen(tester, prefs: openReadPrefs, [
        for (var i = 1; i <= 12; i++) _session('c$i', '#S-${i.toString().padLeft(2, '0')}', _at(0, 8), unread: true),
      ]);
      // Highest numbers first: c12 is on top, c1 far below.
      await tester.pump(const Duration(seconds: 4));
      final repo = container.read(synthesisRepositoryProvider);
      expect(repo.firstWhere((c) => c.clusterId == 'c12').isUnread, isFalse);
      expect(repo.firstWhere((c) => c.clusterId == 'c1').isUnread, isTrue, reason: 'never on screen');

      // The lazy list only knows its length once the cards are built: scroll until c1 is there.
      await tester.scrollUntilVisible(card('c1'), 400, scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(container.read(synthesisRepositoryProvider).firstWhere((c) => c.clusterId == 'c1').isUnread, isTrue);
      await tester.pump(const Duration(milliseconds: 2800));
      expect(container.read(synthesisRepositoryProvider).firstWhere((c) => c.clusterId == 'c1').isUnread, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(synthesisRepositoryProvider).firstWhere((c) => c.clusterId == 'c1').isUnread, isFalse);
      await unmount(tester);
    });

    testWidgets('nothing is read while another tab is in front', (tester) async {
      await pumpScreen(tester, prefs: openReadPrefs, [_session('a', '#S-01', _at(0), unread: true)], shellTab: ShellTab.capture);

      await tester.pump(const Duration(seconds: 10));
      expect(container.read(synthesisRepositoryProvider).single.isUnread, isTrue);

      container.read(selectedShellTabProvider.notifier).select(ShellTab.synthesis);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3100));
      expect(container.read(synthesisRepositoryProvider).single.isUnread, isFalse);
      await unmount(tester);
    });
  });

  group('A request to show one session', () {
    List<SynthesisCluster> many() => [
          for (var i = 1; i <= 25; i++)
            _session('c$i', '#S-${i.toString().padLeft(2, '0')}', _at(0, 8), folder: i == 1 ? 'Ideas' : 'Work'),
        ];

    testWidgets('scrolls the card into view, glows for about 1.5 s, then clears the request', (tester) async {
      await pumpScreen(tester, many());
      expect(card('c1'), findsNothing, reason: 'far below, not built yet');

      container.read(synthesisFocusRequestProvider.notifier).request('c1');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(synthesisFocusRequestProvider), isNull, reason: 'consumed');
      expect(card('c1'), findsOneWidget);
      final top = tester.getTopLeft(card('c1')).dy;
      expect(top, inInclusiveRange(0, 700));

      BoxDecoration decoration() => tester.widget<AnimatedContainer>(card('c1')).decoration! as BoxDecoration;
      await tester.pump(const Duration(milliseconds: 450));
      expect(decoration().boxShadow, isNotEmpty, reason: 'highlighted');

      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(decoration().boxShadow, isEmpty, reason: 'back to normal');
      await unmount(tester);
    });

    testWidgets('filters that would hide the session are reset', (tester) async {
      await pumpScreen(tester, [
        _session('a', '#S-02', _at(0, 11), unread: true, folder: 'Work'),
        _session('b', '#S-01', _at(0, 9), folder: 'Personal'),
      ]);

      await tester.tap(find.byKey(const Key('synthesis_folder_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('triage_chip_unread')));
      await tester.pumpAndSettle();
      expect(card('b'), findsNothing);
      await tester.tap(find.byKey(const Key('folder_panel_row_Work')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folder_panel')), findsNothing, reason: 'choosing a folder closes the panel');

      container.read(synthesisFocusRequestProvider.notifier).request('b');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(card('b'), findsOneWidget);
      expect(find.byKey(const Key('synthesis_filter_badge')), findsNothing, reason: 'the triage filter is back to All');
      expect(find.text('All notes'), findsOneWidget, reason: 'the folder button reads All notes again');
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('a session that no longer exists shows a message and consumes the request', (tester) async {
      await pumpScreen(tester, [_session('a', '#S-01', _at(0))]);

      container.read(synthesisFocusRequestProvider.notifier).request('gone');
      await tester.pump();
      await tester.pump();

      expect(find.text('That note no longer exists.'), findsOneWidget);
      expect(container.read(synthesisFocusRequestProvider), isNull);
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('a request made before the screen existed is honoured when it appears', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final holder = <ProviderContainer>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(NotesRepository()),
            synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(many())),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              holder.add(ProviderScope.containerOf(context));
              return MaterialApp(
                home: Scaffold(
                  body: ref.watch(_showScreen) ? const SynthesisScreen() : const SizedBox(),
                ),
              );
            },
          ),
        ),
      );
      holder.last.read(synthesisFocusRequestProvider.notifier).request('c1');
      holder.last.read(_showScreen.notifier).show();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(card('c1'), findsOneWidget);
      expect(holder.last.read(synthesisFocusRequestProvider), isNull);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });
  });
}

class _Show extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
}

final _showScreen = NotifierProvider<_Show, bool>(_Show.new);

class _FixedTab extends SelectedShellTabNotifier {
  final ShellTab initial;
  _FixedTab(this.initial);

  @override
  ShellTab? build() => initial;
}
