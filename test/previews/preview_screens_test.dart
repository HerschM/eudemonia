import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../previews/gallery_shell.dart';
import '../../previews/screens/capture_screen_preview.dart';
import '../../previews/screens/synthesis_screen_preview.dart';
import '../../previews/screens/insights_screen_preview.dart';
import '../../previews/screens/action_screen_preview.dart';

void main() {
  group('Four-Stage Preview Screens Widget Tests', () {
    testWidgets(
        'CaptureScreenPreview renders with strict header order, status colors, compact dual dropdown filters, and clean floating trigger',
        (tester) async {
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
      expect(
          find.textContaining('Transcribing audio & cleaning speech...'), findsOneWidget); // Yellow pending

      // Verify date-time format: DD/MM  HH:MM AM/PM
      expect(find.textContaining(RegExp(r'\d{2}/\d{2}\s\s\d{2}:\d{2}\s[AP]M')),
          findsWidgets);

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

      expect(numRect.left, lessThan(playRect.left),
          reason: '# Number must be left of Play Button');
      expect(playRect.left, lessThan(unreadRect.left),
          reason: 'Play Button must be left of Unread Dot');
      expect(unreadRect.left, lessThan(deleteRect.left),
          reason: 'Unread Dot must be left of Delete button');

      // Verify Capture card only has manual Edit, NO AI Style button
      expect(find.byKey(const Key('edit_button_note_4')), findsOneWidget);
      expect(find.byKey(const Key('style_button_note_4')), findsNothing);

      // Verify Dual Dropdown Filters are present
      expect(find.byKey(const Key('capture_triage_filter_dropdown')),
          findsOneWidget);
      expect(find.byKey(const Key('capture_status_filter_dropdown')),
          findsOneWidget);

      // Floating Trigger Button with larger mic and "/" separator
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
      expect(find.text('/'), findsOneWidget);
      expect(find.text('Press Vol Up + Down to Capture'), findsOneWidget);

      // Test Floating Button Tap -> transforms into active recording with listening waveform
      await tester.tap(find.byKey(const Key('floating_capture_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('floating_capture_button_active')),
          findsOneWidget);
      expect(find.textContaining('Tap to Stop'), findsOneWidget);

      // Tap again to stop and enqueue new yellow pending note
      await tester.tap(find.byKey(const Key('floating_capture_button_active')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);

      // Verify clean SnackBar copy without debug filler text
      expect(find.text('Captured a new note [#07]'), findsOneWidget);
      expect(find.textContaining('Enqueued as yellow pending note'),
          findsNothing);

      // Test Dual Filter 1: Triage Filter Dropdown (All, Unread, Read)
      await tester.tap(find.byKey(const Key('capture_triage_filter_dropdown')));
      await tester.pumpAndSettle();
      // Select Unread from dropdown menu
      await tester.tap(find.text('Triage: Unread').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unread_dot_note_6')), findsOneWidget);

      // Reset Triage filter
      await tester.tap(find.byKey(const Key('capture_triage_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Triage: All').last);
      await tester.pumpAndSettle();

      // Test Dual Filter 2: Processing Status Filter Dropdown
      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Processing').last);
      await tester.pumpAndSettle();
      expect(find.text('#06'), findsOneWidget);
      expect(find.text('#04'), findsNothing); // Filtered out

      // Filter by Synthesized (Green)
      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthesized').last);
      await tester.pumpAndSettle();
      expect(find.text('#03'), findsOneWidget);
      expect(find.textContaining('Synthesized in #S-01'), findsOneWidget);

      // Filter by Failed (Red)
      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Failed').last);
      await tester.pumpAndSettle();
      expect(find.text('#02'), findsOneWidget);
      expect(find.textContaining('No speech detected in audio recording'),
          findsOneWidget);

      // Reset status filter to All
      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status: All').last);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'SynthesisScreenPreview renders compact folder filter, triage filter, tri-color cards, batch banner, style re-writer, single note lock, and ejection',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SynthesisScreenPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify compact folder and triage filter dropdowns are present
      expect(find.byKey(const Key('synthesis_folder_filter_dropdown')),
          findsOneWidget);
      expect(find.byKey(const Key('synthesis_triage_filter_dropdown')),
          findsOneWidget);

      // Verify pending batch synthesis banner is visible
      expect(find.byKey(const Key('pending_synthesis_batch_banner')),
          findsOneWidget);
      expect(find.textContaining('2 raw thoughts ready to cluster'),
          findsOneWidget);

      // Verify synthesized notes
      expect(find.text('#S-02'), findsOneWidget);
      expect(find.text('#S-01'), findsOneWidget);

      // Verify tri-color cards & unread dot on #S-02
      expect(find.byKey(const Key('unread_dot_S-02')), findsOneWidget);
      expect(find.byKey(const Key('awaiting_action_badge_S-01')), findsOneWidget);

      // Tap #S-02 to mark as read
      await tester.tap(find.text('#S-02'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unread_dot_S-02')), findsNothing);

      // Test Triage Dropdown Filter (All, Unread, Read)
      await tester.tap(find.byKey(const Key('synthesis_triage_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read').last);
      await tester.pumpAndSettle();
      expect(find.text('#S-01'), findsOneWidget);
      expect(find.text('#S-02'), findsOneWidget); // marked read above

      await tester.tap(find.byKey(const Key('synthesis_triage_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Triage').last);
      await tester.pumpAndSettle();

      // Tap Synthesize Now button on the batch banner
      final bannerBtn = find.byKey(const Key('synthesize_now_banner_button'));
      expect(bannerBtn, findsOneWidget);
      await tester.tap(bannerBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pending_synthesis_batch_banner')), findsNothing);
      expect(find.text('Triggered on-demand synthesis clustering.'), findsOneWidget);

      // Verify predefined folder badge with reassignment
      expect(find.byKey(const Key('folder_badge_S-02')), findsOneWidget);

      // Verify AI Style Re-Writer button exists on Synthesis note #S-02
      final styleButtonS02 = find.byKey(const Key('style_button_S-02'));
      expect(styleButtonS02, findsOneWidget);

      // Tap Style Re-Writer button on #S-02
      await tester.tap(styleButtonS02);
      await tester.pumpAndSettle();

      // Verify Style modal opened
      expect(find.text('AI Style Re-Writer'), findsOneWidget);
      expect(find.text('Concise & Direct'), findsOneWidget);

      // Verify currently active preset has checkmark (tick mark)
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Select a different style preset (e.g. Bullet Points)
      await tester.tap(find.text('Bullet Points'));
      await tester.pumpAndSettle();

      // Verify #S-02 is now marked as re-processing and turns Yellow!
      expect(find.byKey(const Key('reprocessing_badge_S-02')), findsOneWidget);
      expect(find.text('Re-synthesizing...'), findsOneWidget);

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
      final expandPillS01Finder =
          find.byKey(const Key('expand_origin_pill_S-01'));
      expect(expandPillS01Finder, findsOneWidget);
      await tester.ensureVisible(expandPillS01Finder);
      await tester.pumpAndSettle();
      await tester.tap(expandPillS01Finder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('move_out_button_raw_yesterday_1')),
          findsNothing);

      // Collapse #S-01 and re-expand #S-02 to perform Move Out
      await tester.ensureVisible(expandPillS01Finder);
      await tester.tap(expandPillS01Finder);
      await tester.pumpAndSettle();

      await tester.ensureVisible(expandPillFinder);
      await tester.tap(expandPillFinder);
      await tester.pumpAndSettle();

      // Tap Move Out on raw_1 from #S-02 to open ejection modal
      final moveOutRaw1Finder = find.byKey(const Key('move_out_button_raw_1'));
      await tester.ensureVisible(moveOutRaw1Finder);
      await tester.tap(moveOutRaw1Finder);
      await tester.pumpAndSettle();

      expect(find.text('Reassign Raw Note [#01]'), findsOneWidget);
      expect(find.byKey(const Key('move_to_another_clubbed_note_btn')),
          findsOneWidget);

      // Verify note ejection modal copy is clean without instructional filler text
      expect(find.textContaining('both will turn yellow for re-synthesis'),
          findsNothing);

      // Tap Move to another clubbed note -> reveals target cluster selector
      await tester.tap(find.byKey(const Key('move_to_another_clubbed_note_btn')));
      await tester.pumpAndSettle();

      expect(find.text('SELECT TARGET CLUBBED NOTE'), findsOneWidget);
      expect(
          find.textContaining('Moving will mark both source and target'),
          findsNothing);
      expect(find.byKey(const Key('select_target_cluster_cluster_1')),
          findsOneWidget);

      // Select cluster_1 as target
      await tester.tap(find.byKey(const Key('select_target_cluster_cluster_1')));
      await tester.pumpAndSettle();

      // Verify both source (#S-02) and target (#S-01) now display the yellow re-synthesizing badge!
      expect(find.byKey(const Key('reprocessing_badge_S-02')), findsOneWidget);
      expect(find.byKey(const Key('reprocessing_badge_S-01')), findsOneWidget);

      // Verify clean SnackBar copy
      expect(find.text('Moved [#01] to #S-01'), findsOneWidget);

      // Dismiss SnackBar to clear overlay
      ScaffoldMessenger.of(tester.element(find.byType(SynthesisScreenPreview)))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Test Explicit Note Merging: Tap Merge button on #S-02
      final mergeBtnS02 = find.byKey(const Key('merge_button_S-02'));
      await tester.scrollUntilVisible(mergeBtnS02, -200);
      await tester.pumpAndSettle();
      expect(mergeBtnS02, findsOneWidget);
      await tester.tap(mergeBtnS02);
      await tester.pumpAndSettle();

      // Verify NoteMergeModal opened
      expect(find.text('Merge Session #S-02'), findsOneWidget);
      expect(find.text('SELECT TARGET SESSION'), findsOneWidget);
      expect(find.byKey(const Key('select_target_merge_cluster_1')),
          findsOneWidget);

      // Tap select target cluster_1 (#S-01)
      await tester.tap(find.byKey(const Key('select_target_merge_cluster_1')));
      await tester.pumpAndSettle();

      // Verify SnackBar and State Consolidation
      expect(find.text('Merged [#S-02] into #S-01'), findsOneWidget);
      expect(find.text('#S-02'), findsNothing,
          reason: '#S-02 should be consolidated into #S-01 and removed');
      expect(find.text('#S-01'), findsOneWidget);
      expect(find.byKey(const Key('reprocessing_badge_S-01')), findsOneWidget);
    });

    testWidgets(
        'InsightsScreenPreview renders sub-views and coherence breath trigger',
        (tester) async {
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

    testWidgets(
        'ActionScreenPreview renders commitments and calendar time blocks',
        (tester) async {
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
      expect(
          find.textContaining('Verify accessibility debouncer on locked phone'),
          findsOneWidget);
      expect(find.text('⚡ High Urgency'), findsOneWidget);

      // Time block preview
      expect(find.textContaining('SCHEDULE TIME-BLOCKS'), findsOneWidget);
      expect(find.textContaining('Push to Calendar'), findsOneWidget);
    });

    testWidgets(
        'GalleryShell switches across all 4 stages with zero-suppression tabs, AI pipeline HUD modal, and settings preview on 360dp viewport with 0 overflows',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: GalleryShell(),
        ),
      );
      await tester.pumpAndSettle();

      // Zero-suppression stage tabs visible with human unconsumed value numbers
      expect(find.text('Capture (2)'), findsOneWidget);
      expect(find.text('Synthesis (1)'), findsOneWidget);
      expect(find.text('Insights (1)'), findsOneWidget);
      expect(find.text('Action (3)'), findsOneWidget);

      // Top AI pipeline pill is visible and interactive
      final pipelinePill = find.byKey(const Key('top_ai_pipeline_pill'));
      expect(pipelinePill, findsOneWidget);
      expect(find.textContaining('3 in Pipeline'), findsOneWidget);

      // Tap Top AI pipeline pill to open HUD modal
      await tester.tap(pipelinePill);
      await tester.pumpAndSettle();

      expect(find.text('Mind Pipeline Status'), findsOneWidget);
      expect(find.textContaining('audio recording transcribing'), findsOneWidget);
      expect(find.textContaining('raw thoughts ready to cluster'), findsOneWidget);
      expect(find.textContaining('Next daily refresh in 14h'), findsOneWidget);
      expect(find.textContaining('All action commitments extracted'), findsOneWidget);

      // Tap Synthesize Now in Pipeline HUD Modal
      final hudSynthesizeBtn = find.byKey(const Key('hud_synthesize_now_button'));
      expect(hudSynthesizeBtn, findsOneWidget);
      await tester.tap(hudSynthesizeBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Synthesized 2 raw thoughts'), findsOneWidget);
      // Status is updated to 1 in pipeline (capture note transcribing remains)
      expect(find.textContaining('1 in Pipeline'), findsOneWidget);

      // Tap Settings gear button to open Settings & Diagnostics preview screen
      final settingsGear = find.byKey(const Key('settings_gear_button'));
      expect(settingsGear, findsOneWidget);
      await tester.tap(settingsGear);
      await tester.pumpAndSettle();

      expect(find.text('Settings & Diagnostics'), findsOneWidget);
      expect(find.text('Accessibility Interceptor'), findsOneWidget);
      expect(find.text('ENABLED'), findsWidgets);
      expect(find.byKey(const Key('synthesis_note_threshold_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('synthesis_inactivity_minutes_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('trigger_synthesis_now_btn')), findsOneWidget);

      // Verify Folder Management & Semantic Manifestos Section
      final folderHeaderFinder =
          find.text('FOLDER MANAGEMENT & SEMANTIC MANIFESTOS');
      await tester.scrollUntilVisible(folderHeaderFinder, 300);
      await tester.pumpAndSettle();
      expect(folderHeaderFinder, findsOneWidget);
      expect(find.byKey(const Key('folder_item_work')), findsOneWidget);
      expect(find.byKey(const Key('folder_item_eudemonia')), findsOneWidget);

      // Tap Edit on Work folder manifesto
      final editWorkBtn = find.byKey(const Key('edit_manifesto_work'));
      await tester.tap(editWorkBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Description for "Work"'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('edit_folder_desc_field')),
          'Client projects and technical design docs.');
      await tester.tap(find.byKey(const Key('confirm_edit_folder_button')));
      await tester.pumpAndSettle();
      expect(find.text('Client projects and technical design docs.'),
          findsOneWidget);

      // Tap Add Custom Folder
      final addFolderBtn = find.byKey(const Key('add_custom_folder_button'));
      await tester.scrollUntilVisible(addFolderBtn, 200);
      await tester.pumpAndSettle();
      await tester.tap(addFolderBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_add_folder_button')), findsOneWidget);
      expect(find.byKey(const Key('new_folder_name_field')), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('new_folder_name_field')), 'Health & Fitness');
      await tester.enterText(find.byKey(const Key('new_folder_desc_field')),
          'Workout logs, nutrition notes, running pace, and recovery.');
      await tester.tap(find.byKey(const Key('confirm_add_folder_button')));
      await tester.pumpAndSettle();

      expect(find.text('Health & Fitness'), findsOneWidget);

      final evictBtnFinder = find.byKey(const Key('evict_models_btn'));
      await tester.scrollUntilVisible(evictBtnFinder, 300);
      await tester.pumpAndSettle();
      expect(evictBtnFinder, findsOneWidget);
      expect(find.text('1.58 GB'), findsOneWidget);

      // Tap back button from Settings
      await tester.scrollUntilVisible(find.byKey(const Key('settings_back_button')), -300);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_back_button')));
      await tester.pumpAndSettle();

      // Back in GalleryShell - switch to Synthesis (unread count was incremented to 2 after HUD synthesis)
      await tester.tap(find.text('Synthesis (2)'));
      await tester.pumpAndSettle();
      expect(find.text('#S-02'), findsOneWidget);

      // Switch to Insights
      await tester.tap(find.text('Insights (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Emotion Map'), findsOneWidget);

      // Switch to Action
      await tester.tap(find.text('Action (3)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Device Calendar'), findsOneWidget);
    });
  });
}
