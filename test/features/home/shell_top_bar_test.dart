import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';

import 'shell_test_harness.dart';

/// User decision 16 (2026-11-28): no app title; the pipeline chip, the Capture | Synthesis tabs and
/// the Settings gear share one row under the status bar.
void main() {
  setUp(mockShellChannels);
  tearDown(unmockShellChannels);

  final shell = ShellHarness();

  // Twelve unread thoughts and twelve unread notes: two-digit counts on both tabs.
  List<Note> unreadThoughts() => [for (var i = 0; i < 12; i++) Note(correctedText: 'Thought $i', state: ThoughtState.processed)];
  final unreadNotes = [for (var i = 1; i <= 12; i++) shellTestCluster(i, unread: true)];

  const states = <String, PipelineStatus>{
    'In Sync ▾': PipelineStatus(),
    '12 in Pipeline ▾': PipelineStatus(readyThoughts: 12),
    'Synthesizing…': PipelineStatus(synthesizing: true),
  };

  for (final entry in states.entries) {
    testWidgets('the top row fits 360 dp with "${entry.key}" on the chip and two-digit counts', (tester) async {
      final realFont = await loadRealFonts();
      await shell.pump(tester, notes: unreadThoughts(), clusters: unreadNotes, status: entry.value, initialIndex: 0);

      expect(find.text('Eudemonia'), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Capture (12)'), findsOneWidget);
      expect(find.text('Synthesis (12)'), findsOneWidget);
      if (entry.key != 'Synthesizing…') expect(find.text(entry.key), findsOneWidget);
      if (entry.key == 'Synthesizing…') expect(find.textContaining('Synthesizing'), findsOneWidget);

      final chip = tester.getRect(find.byKey(const Key('top_ai_pipeline_pill')));
      final tabs = tester.getRect(find.byType(TabBar));
      final gear = tester.getRect(find.byKey(const Key('settings_gear_button')));
      debugPrint('top row "${entry.key}": chip ${chip.left.toStringAsFixed(1)}..${chip.right.toStringAsFixed(1)} '
          '(w ${chip.width.toStringAsFixed(1)}), tabs ${tabs.left.toStringAsFixed(1)}..${tabs.right.toStringAsFixed(1)} '
          '(w ${tabs.width.toStringAsFixed(1)}), gear ${gear.left.toStringAsFixed(1)}..${gear.right.toStringAsFixed(1)} '
          '(w ${gear.width.toStringAsFixed(1)})');

      // Left to right, in the screen, not touching each other.
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(chip.right, lessThanOrEqualTo(tabs.left));
      expect(tabs.right, lessThanOrEqualTo(gear.left));
      expect(gear.right, lessThanOrEqualTo(360));
      // One row under the status bar: all three vertically inside the same band.
      expect(tabs.top, lessThan(60));
      expect(chip.center.dy, closeTo(tabs.center.dy, 1));
      expect(gear.center.dy, closeTo(tabs.center.dy, 1));

      // The tab labels sit inside their tab; set in the phone's font they keep their full size
      // (the chip gives way first, and these texts fit it unscaled).
      for (final label in ['Capture (12)', 'Synthesis (12)']) {
        final text = find.text(label);
        final drawn = tester.getRect(text);
        final tab = tester.getRect(find.widgetWithText(Tab, label));
        expect(drawn.left, greaterThanOrEqualTo(tab.left));
        expect(drawn.right, lessThanOrEqualTo(tab.right));
        if (realFont) {
          expect(drawn.width / tester.getSize(text).width, greaterThan(0.99), reason: '$label is not scaled down');
        }
      }
      if (realFont) {
        final chipText = find.descendant(of: find.byKey(const Key('top_ai_pipeline_pill')), matching: find.byType(Text)).first;
        expect(tester.getRect(chipText).width / tester.getSize(chipText).width, greaterThan(0.99),
            reason: 'the chip text fits its width without scaling');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the chip text is never wider than the chip it is drawn in', (tester) async {
    await shell.pump(tester, status: const PipelineStatus(readyThoughts: 12));
    final chip = tester.getRect(find.byKey(const Key('top_ai_pipeline_pill')));
    final text = tester.getRect(find.text('12 in Pipeline ▾'));
    expect(text.left, greaterThanOrEqualTo(chip.left));
    expect(text.right, lessThanOrEqualTo(chip.right));
  });

  testWidgets('the chip still opens the status sheet and the gear still opens Settings', (tester) async {
    await shell.pump(tester, status: const PipelineStatus());

    await tester.tap(find.byKey(const Key('top_ai_pipeline_pill')));
    await tester.pumpAndSettle();
    expect(find.byType(PipelineHudModal), findsOneWidget);

    await tester.tapAt(const Offset(180, 20)); // the scrim above the sheet
    await tester.pumpAndSettle();
    expect(find.byType(PipelineHudModal), findsNothing);

    await tester.tap(find.byKey(const Key('settings_gear_button')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('the tabs keep switching stages', (tester) async {
    await shell.pump(tester, clusters: [shellTestCluster(1)]);
    await tester.tap(find.text('Synthesis'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('synthesis_mode_toggle')), findsOneWidget);
    await tester.tap(find.text('Capture'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('synthesis_mode_toggle')), findsNothing);
  });

  testWidgets('the pages start right under the top row: the status bar height is not left out twice', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 48);
    addTearDown(tester.view.resetPadding);
    await shell.pump(tester);

    final topRowBottom = tester.getRect(find.byKey(const Key('top_ai_pipeline_pill'))).bottom;
    final viewBarTop = tester.getRect(find.byKey(const Key('capture_view_title'))).top;
    expect(viewBarTop - topRowBottom, lessThan(40), reason: 'no second status-bar gap above the Capture view bar');
  });
}
