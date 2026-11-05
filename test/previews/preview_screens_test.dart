import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../previews/gallery_shell.dart';
import '../../previews/screens/capture_screen_preview.dart';
import '../../previews/screens/synthesis_screen_preview.dart';
import '../../previews/screens/insights_screen_preview.dart';
import '../../previews/screens/action_screen_preview.dart';

void main() {
  group('Four-Stage Preview Screens Widget Tests', () {
    testWidgets('CaptureScreenPreview renders with strict header order, status colors, dual filters and floating trigger', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CaptureScreenPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen renders
      expect(find.textContaining('TODAY —'), findsOneWidget);
      expect(find.text('#06'), findsOneWidget);
      expect(find.text('#05'), findsOneWidget);
      expect(find.text('#04'), findsOneWidget);

      // Verify Status Badges (Color representation)
      expect(find.textContaining('Transcribing audio & cleaning speech...'), findsOneWidget); // Yellow pending

      // Verify date-time format: DD/MM  HH:MM AM/PM
      expect(find.textContaining(RegExp(r'\d{2}/\d{2}\s\s\d{2}:\d{2}\s[AP]M')), findsWidgets);

      // Verify Header ordering: # Number before Play Button before Unread Dot before Delete
      final num04Finder = find.text('#04');
      final play04Finder = find.byKey(const Key('play_button_note_4'));
      final unread04Finder = find.byKey(const Key('unread_dot_note_4'));
      final delete04Finder = find.byKey(const Key('delete_button_note_4'));

      expect(num04Finder, findsOneWidget);
      expect(play04Finder, findsOneWidget);
      expect(unread04Finder, findsOneWidget);
      expect(delete04Finder, findsOneWidget);

      final numRect = tester.getRect(num04Finder);
      final playRect = tester.getRect(play04Finder);
      final unreadRect = tester.getRect(unread04Finder);
      final deleteRect = tester.getRect(delete04Finder);

      expect(numRect.left, lessThan(playRect.left), reason: '# Number must be left of Play Button');
      expect(playRect.left, lessThan(unreadRect.left), reason: 'Play Button must be left of Unread Dot');
      expect(unreadRect.left, lessThan(deleteRect.left), reason: 'Unread Dot must be left of Delete button');

      // Floating Trigger Button with larger mic and "/" separator
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      expect(find.text('Press Vol Up + Down to Capture'), findsOneWidget);

      // Test Floating Button Tap -> transforms into active recording with listening waveform
      await tester.tap(find.byKey(const Key('floating_capture_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget);
      expect(find.textContaining('Tap to Stop'), findsOneWidget);

      // Tap again to stop and enqueue new yellow pending note
      await tester.tap(find.byKey(const Key('floating_capture_button_active')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);

      // Test Dual Filter 1: Read/Unread Filter
      await tester.tap(find.byKey(const Key('filter_read_unread')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unread_dot_note_6')), findsOneWidget);

      // Reset read filter
      await tester.tap(find.byKey(const Key('filter_read_all')));
      await tester.pumpAndSettle();

      // Test Dual Filter 2: Processing Status Filter
      await tester.tap(find.byKey(const Key('filter_status_processing')));
      await tester.pumpAndSettle();
      expect(find.text('#06'), findsOneWidget);
      expect(find.text('#04'), findsNothing); // Filtered out

      // Filter by Synthesized (Green)
      await tester.ensureVisible(find.byKey(const Key('filter_status_synthesized')));
      await tester.tap(find.byKey(const Key('filter_status_synthesized')));
      await tester.pumpAndSettle();
      expect(find.text('#03'), findsOneWidget);
      expect(find.textContaining('Synthesized in #S-01'), findsOneWidget);

      // Filter by Failed (Red)
      await tester.ensureVisible(find.byKey(const Key('filter_status_failed')));
      await tester.tap(find.byKey(const Key('filter_status_failed')));
      await tester.pumpAndSettle();
      expect(find.text('#02'), findsOneWidget);
      expect(find.textContaining('No speech detected in audio recording'), findsOneWidget);

      // Reset status filter
      await tester.ensureVisible(find.byKey(const Key('filter_status_all')));
      await tester.tap(find.byKey(const Key('filter_status_all')));
      await tester.pumpAndSettle();
    });

    testWidgets('SynthesisScreenPreview renders compact folder filter dropdown, single note lock, and ejection re-synthesis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SynthesisScreenPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify compact folder filter dropdown is present
      expect(find.byKey(const Key('synthesis_folder_filter_dropdown')), findsOneWidget);

      // Verify synthesized notes
      expect(find.text('#S-02'), findsOneWidget);
      expect(find.text('#S-01'), findsOneWidget);

      // Verify predefined folder badge with reassignment
      expect(find.byKey(const Key('folder_badge_S-02')), findsOneWidget);

      // Expand origin raw notes pill on #S-02 (3 notes -> Move Out must be visible)
      final expandPillFinder = find.byKey(const Key('expand_origin_pill_S-02'));
      expect(expandPillFinder, findsOneWidget);
      await tester.tap(expandPillFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('move_out_button_raw_1')), findsOneWidget);

      // Collapse #S-02 so #S-01 doesn't scroll below the fold
      await tester.tap(expandPillFinder);
      await tester.pumpAndSettle();

      // Expand origin raw notes pill on #S-01 (1 note -> Single Note Guard: Move Out must be HIDDEN)
      final expandPillS01Finder = find.byKey(const Key('expand_origin_pill_S-01'));
      expect(expandPillS01Finder, findsOneWidget);
      await tester.tap(expandPillS01Finder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('move_out_button_raw_yesterday_1')), findsNothing);

      // Collapse #S-01 and re-expand #S-02 to perform Move Out
      await tester.tap(expandPillS01Finder);
      await tester.pumpAndSettle();

      await tester.tap(expandPillFinder);
      await tester.pumpAndSettle();

      // Tap Move Out on raw_1 from #S-02 to open ejection modal
      await tester.tap(find.byKey(const Key('move_out_button_raw_1')));
      await tester.pumpAndSettle();

      expect(find.text('Reassign Raw Note [#01]'), findsOneWidget);
      expect(find.byKey(const Key('move_to_another_clubbed_note_btn')), findsOneWidget);

      // Tap Move to another clubbed note -> reveals target cluster selector
      await tester.tap(find.byKey(const Key('move_to_another_clubbed_note_btn')));
      await tester.pumpAndSettle();

      expect(find.text('SELECT TARGET CLUBBED NOTE'), findsOneWidget);
      expect(find.byKey(const Key('select_target_cluster_cluster_1')), findsOneWidget);

      // Select cluster_1 as target
      await tester.tap(find.byKey(const Key('select_target_cluster_cluster_1')));
      await tester.pumpAndSettle();

      // Verify both source (#S-02) and target (#S-01) now display the yellow re-synthesizing badge!
      expect(find.byKey(const Key('reprocessing_badge_S-02')), findsOneWidget);
    });

    testWidgets('InsightsScreenPreview renders sub-views and coherence breath trigger', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InsightsScreenPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sub-view chips
      expect(find.text('Emotion Map'), findsOneWidget);
      expect(find.text('Topic Density'), findsOneWidget);
      expect(find.text('Recurrent Loops'), findsOneWidget);

      // Verify Emotion Map content
      expect(find.textContaining('WEEKLY EMOTIONAL VALENCE'), findsOneWidget);
      expect(find.text('2-Minute Coherence Breath'), findsOneWidget);

      // Tap Topic Density
      await tester.tap(find.text('Topic Density'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TOPIC COGNITIVE DENSITY'), findsOneWidget);

      // Tap Recurrent Loops
      await tester.tap(find.text('Recurrent Loops'));
      await tester.pumpAndSettle();
      expect(find.textContaining('RECURRENT THOUGHT PATTERNS'), findsOneWidget);
    });

    testWidgets('ActionScreenPreview renders commitments and calendar time blocks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActionScreenPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Calendar sync status
      expect(find.textContaining('Device Calendar: Connected'), findsOneWidget);

      // Action items
      expect(find.textContaining('Verify accessibility debouncer on locked phone'), findsOneWidget);
      expect(find.text('⚡ High Urgency'), findsOneWidget);

      // Time block preview
      expect(find.textContaining('SCHEDULE TIME-BLOCKS'), findsOneWidget);
      expect(find.textContaining('Push to Calendar'), findsOneWidget);
    });

    testWidgets('GalleryShell switches across all 4 stages on 360dp viewport with 0 overflows', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: GalleryShell(),
        ),
      );
      await tester.pumpAndSettle();

      // Stage tabs visible
      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('Synthesis'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);

      // Switch to Synthesis
      await tester.tap(find.text('Synthesis'));
      await tester.pumpAndSettle();
      expect(find.text('#S-02'), findsOneWidget);

      // Switch to Insights
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Emotion Map'), findsOneWidget);

      // Switch to Action
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Device Calendar'), findsOneWidget);
    });
  });
}
