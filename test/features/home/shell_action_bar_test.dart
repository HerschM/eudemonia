import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/presentation/glass_bubble.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';
import 'package:eudemonia/features/search/presentation/search_page.dart';
import 'package:eudemonia/features/synthesis/presentation/note_row.dart';

import 'shell_test_harness.dart';

/// User decisions 7 and 13 (2026-11-28): the bottom row is a round pen bubble, an obround search
/// bubble and a round microphone bubble (icon only), translucent and glass-like; while recording
/// the search bubble shows the timer.
void main() {
  setUp(mockShellChannels);
  tearDown(unmockShellChannels);

  final shell = ShellHarness();

  final pen = find.byKey(const Key('write_note_button'));
  final search = find.byKey(const Key('shell_search_button'));
  final mic = find.byKey(const Key('floating_capture_button'));
  final micActive = find.byKey(const Key('floating_capture_button_active'));

  Future<void> startRecording(WidgetTester tester) async {
    await tester.tap(mic);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('idle', () {
    testWidgets('three bubbles in one row: pen, obround search, mic, 16 dp margins, 10 dp gaps, 52 dp high',
        (tester) async {
      await shell.pump(tester);

      final p = tester.getRect(pen);
      final s = tester.getRect(search);
      final m = tester.getRect(mic);
      for (final r in [p, s, m]) {
        expect(r.height, closeTo(52, 0.01));
      }
      expect(p.width, closeTo(52, 0.01));
      expect(m.width, closeTo(52, 0.01));
      expect(p.left, closeTo(16, 0.01));
      expect(m.right, closeTo(344, 0.01));
      expect(s.left - p.right, closeTo(10, 0.01));
      expect(m.left - s.right, closeTo(10, 0.01));
      expect(s.width, greaterThan(150), reason: 'the search bubble takes the remaining width');
      expect(p.center.dy, closeTo(s.center.dy, 0.1));
      expect(m.center.dy, closeTo(s.center.dy, 0.1));
      expect(m.bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the mic bubble has only the mic symbol, the pen has a tooltip, search says Search', (tester) async {
      await shell.pump(tester);

      // User decision 7: no `Tap to capture` text, only the mic symbol.
      expect(find.text('Tap to capture'), findsNothing);
      expect(find.descendant(of: mic, matching: find.byType(Text)), findsNothing);
      expect(find.descendant(of: mic, matching: find.byIcon(Icons.mic)), findsOneWidget);
      expect(find.descendant(of: pen, matching: find.byType(Text)), findsNothing);
      expect(find.descendant(of: search, matching: find.byIcon(Icons.search)), findsOneWidget);
      expect(find.descendant(of: search, matching: find.text('Search')), findsOneWidget);
      expect(find.byTooltip('Write a thought'), findsOneWidget);
      expect(find.byTooltip('Record a thought'), findsOneWidget);
      expect(find.byKey(const Key('recording_timer_text')), findsNothing);
    });

    testWidgets('semantics name the pen, the search and the record bubble', (tester) async {
      final handle = tester.ensureSemantics();
      await shell.pump(tester);

      final penNode = tester.getSemantics(pen);
      expect(penNode.label, 'Write a thought');
      expect(penNode.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('Record a thought'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsWidgets);
      handle.dispose();
    });

    testWidgets('each bubble is clipped and blurs behind itself; nothing else blurs', (tester) async {
      await shell.pump(tester);

      expect(find.byType(BackdropFilter), findsNWidgets(3), reason: 'one blur per bubble, never a full-width layer');
      for (final bubble in [pen, search, mic]) {
        expect(find.descendant(of: bubble, matching: find.byType(BackdropFilter)), findsOneWidget);
        expect(find.descendant(of: bubble, matching: find.byType(ClipRRect)), findsOneWidget);
        final box = tester.getSize(find.descendant(of: bubble, matching: find.byType(BackdropFilter)));
        expect(box.height, 52);
        expect(box.width, lessThan(330), reason: 'the blur covers the bubble only');
      }
    });

    testWidgets('the bubbles are translucent: the surface colour is about 55 percent opaque', (tester) async {
      await shell.pump(tester);

      final decoration = tester
          .widgetList<DecoratedBox>(find.descendant(of: search, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(decoration.color!.a, closeTo(0.55, 0.01));
      expect((decoration.border as Border).top.width, 1.0);
    });

    testWidgets('the pen opens the written-note sheet', (tester) async {
      await shell.pump(tester);

      await tester.tap(pen);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('written_note_field')), findsOneWidget);
      expect(find.byType(GlassBubble), findsNWidgets(3)); // the row stays under the sheet
    });

    testWidgets('the search bubble opens the search page', (tester) async {
      await shell.pump(tester);

      await tester.tap(search);
      await tester.pumpAndSettle();

      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.byKey(const Key('search_field')), findsOneWidget);
    });

    testWidgets('the row is on Synthesis too', (tester) async {
      await shell.pump(tester, clusters: [shellTestCluster(1)]);
      await tester.tap(find.text('Synthesis'));
      await tester.pumpAndSettle();

      expect(pen, findsOneWidget);
      expect(search, findsOneWidget);
      expect(mic, findsOneWidget);
    });
  });

  group('recording', () {
    testWidgets('the mic becomes a solid stop bubble and search gives way to the timer', (tester) async {
      await shell.pump(tester);
      await startRecording(tester);

      expect(shell.native.state.isRecording, isTrue);
      expect(micActive, findsOneWidget);
      expect(mic, findsNothing);
      expect(find.descendant(of: micActive, matching: find.byIcon(Icons.stop_rounded)), findsOneWidget);
      expect(find.descendant(of: micActive, matching: find.byType(Text)), findsNothing);
      expect(find.byTooltip('Stop recording'), findsOneWidget);
      // The timer replaces search: same slot, search not available.
      expect(search, findsNothing);
      expect(find.byKey(const Key('recording_dot')), findsOneWidget);
      expect(find.byKey(const Key('recording_timer_text')), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('recording_timer_text'))).center.dx, closeTo(180, 40));
      // Blur only where bubbles are glass: the pen and the timer; the stop bubble is a solid tint.
      expect(find.byType(BackdropFilter), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the timer shows the limit native reports', (tester) async {
      await shell.pump(tester, maxDurationMs: 300000);
      await startRecording(tester);

      // User decision 13: `00:00 / 05:00` in the middle bubble.
      expect(find.text('00:00 / 05:00'), findsOneWidget);
    });

    testWidgets('semantics say Stop recording', (tester) async {
      final handle = tester.ensureSemantics();
      await shell.pump(tester);
      await startRecording(tester);

      expect(find.bySemanticsLabel('Stop recording'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('stopping brings search back and says which note was captured', (tester) async {
      await shell.pump(tester);
      await startRecording(tester);

      await tester.tap(micActive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(shell.native.state.isRecording, isFalse);
      expect(search, findsOneWidget);
      expect(find.byKey(const Key('recording_timer_text')), findsNothing);
      expect(find.text('Captured a new note [#01]'), findsOneWidget);
    });

    testWidgets('the state carries over when the tab changes', (tester) async {
      await shell.pump(tester, clusters: [shellTestCluster(1)]);
      await startRecording(tester);
      await tester.tap(find.text('Synthesis'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(micActive, findsOneWidget);
      expect(find.byKey(const Key('recording_timer_text')), findsOneWidget);
    });
  });

  group('SnackBars and scrolling', () {
    testWidgets('the Captured message is laid out above all three bubbles, never over them', (tester) async {
      await shell.pump(tester);
      await startRecording(tester);
      await tester.tap(micActive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final snackBar = tester.getRect(find.byType(SnackBar));
      expect(find.byType(SnackBar), findsOneWidget);
      for (final bubble in [pen, search, mic]) {
        expect(snackBar.overlaps(tester.getRect(bubble)), isFalse, reason: 'snackbar $snackBar bubble ${tester.getRect(bubble)}');
      }
    });

    testWidgets('the Saved a written note message does not cover the bubbles either', (tester) async {
      await shell.pump(tester);
      await tester.tap(pen);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('written_note_field')), 'A written thought');
      await tester.pump();
      await tester.tap(find.byKey(const Key('written_note_save')));
      await tester.pumpAndSettle();

      final snackBar = find.textContaining('Saved a written note');
      expect(snackBar, findsOneWidget);
      final bar = tester.getRect(find.byType(SnackBar));
      for (final bubble in [pen, search, mic]) {
        expect(bar.overlaps(tester.getRect(bubble)), isFalse);
      }
    });

    testWidgets('the last thought on Capture scrolls clear of the row', (tester) async {
      await shell.pump(tester, notes: [
        for (var i = 0; i < 14; i++)
          Note(correctedText: 'Thought number $i', state: ThoughtState.processed, isRead: true, dailySequenceNumber: i + 1),
      ]);

      await tester.fling(find.byType(ListView).first, const Offset(0, -6000), 4000);
      await tester.pumpAndSettle();

      final lastCard = tester.getRect(find.byType(ThoughtCard).last);
      final barTop = [pen, search, mic].map((f) => tester.getRect(f).top).reduce((a, b) => a < b ? a : b);
      expect(lastCard.bottom, lessThanOrEqualTo(barTop), reason: 'last card $lastCard, bubbles from $barTop');
    });

    testWidgets('the last note on Synthesis scrolls clear of the row', (tester) async {
      await shell.pump(tester, clusters: [for (var i = 1; i <= 14; i++) shellTestCluster(i)]);
      await tester.tap(find.text('Synthesis'));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(ListView).last, const Offset(0, -6000), 4000);
      await tester.pumpAndSettle();

      final lastRow = tester.getRect(find.byType(NoteRow).last);
      final barTop = [pen, search, mic].map((f) => tester.getRect(f).top).reduce((a, b) => a < b ? a : b);
      expect(lastRow.bottom, lessThanOrEqualTo(barTop), reason: 'last note $lastRow, bubbles from $barTop');
    });
  });

  testWidgets('the row steps aside while the keyboard is up, and stays during a recording', (tester) async {
    await shell.pump(tester);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    // The Scaffold animates its floating slot out and in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('shell_search_button')), findsNothing, reason: 'nothing may cover an editor and its Save');
    expect(find.byKey(const Key('floating_capture_button')), findsNothing);

    tester.view.resetViewInsets();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('floating_capture_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget, reason: 'stop stays within reach');
  });
}
