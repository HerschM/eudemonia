import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../previews/gallery_shell.dart';
import '../../previews/screens/capture_screen_preview.dart';
import '../../previews/screens/synthesis_screen_preview.dart';
import '../../previews/screens/insights_screen_preview.dart';
import '../../previews/screens/action_screen_preview.dart';
import '../../previews/screens/model_setup_preview.dart';

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
      expect(find.text('Tap to capture'), findsOneWidget);

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
      expect(find.textContaining('Speech recognition stopped unexpectedly'),
          findsOneWidget);

      // Reset status filter to All
      await tester.tap(find.byKey(const Key('capture_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status: All').last);
      await tester.pumpAndSettle();
    });

    group('SynthesisScreenPreview (production SynthesisView on mock scenarios) on 360dp', () {
      Future<void> pumpPreview(WidgetTester tester, {int scenario = 0}) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SynthesisScreenPreview(initialScenario: scenario)),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder card(String id) => find.byKey(Key('synthesis_cluster_card_$id'));

      /// The list builds rows as they scroll in: brings [finder] into view.
      Future<void> reveal(WidgetTester tester, Finder finder) async {
        await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }

      testWidgets('many notes: collapsed rows by day with the bar, the banner and no overflow', (tester) async {
        await pumpPreview(tester);

        // The bar replaces the header and the two dropdown filters.
        expect(find.text('SYNTHESIS SESSIONS'), findsNothing);
        expect(find.byKey(const Key('synthesis_folder_button')), findsOneWidget);
        expect(find.text('All notes'), findsOneWidget);
        expect(find.byKey(const Key('synthesis_mode_toggle')), findsOneWidget);
        expect(find.byKey(const Key('synthesis_expand_all_toggle')), findsOneWidget);

        // Verify pending batch synthesis banner is visible
        expect(find.byKey(const Key('pending_synthesis_batch_banner')), findsOneWidget);
        expect(find.text('2 thoughts ready for Synthesis'), findsOneWidget);

        // One row per note: number, title, folder under the title, unread dot; nothing is open.
        expect(find.textContaining('TODAY —'), findsOneWidget);
        expect(card('n24'), findsOneWidget);
        expect(find.text('#S-06'), findsOneWidget);
        expect(find.text('Roadmap review'), findsOneWidget);
        expect(find.byKey(const Key('unread_dot_n24')), findsOneWidget);
        expect(find.byKey(const Key('expand_raw_notes_n24')), findsNothing);
        expect(find.byKey(const Key('style_button_n24')), findsNothing);
        // A note waiting for its rewrite shows the thinking indicator in place of its time.
        expect(find.text('Rewriting…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('tapping a row opens the note and reads it; tapping again closes it', (tester) async {
        await pumpPreview(tester);

        await tester.tap(find.byKey(const Key('note_row_n24')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('unread_dot_n24')), findsNothing, reason: 'opening reads the note');
        expect(find.text('From 3 thoughts'), findsOneWidget);
        expect(find.text('Decide the order of the next three releases.'), findsOneWidget);

        await tester.tap(find.byKey(const Key('note_row_n24')));
        await tester.pumpAndSettle();
        expect(find.text('From 3 thoughts'), findsNothing);
      });

      testWidgets('Synthesize Now shows the run, then the banner goes', (tester) async {
        await pumpPreview(tester);

        await tester.tap(find.byKey(const Key('synthesize_now_banner_button')));
        await tester.pump();
        expect(find.text('Synthesizing…'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2600));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pending_synthesis_batch_banner')), findsNothing);
        expect(find.text('Triggered on-demand synthesis clustering.'), findsOneWidget);
      });

      testWidgets('Read mode: the note and its thoughts, none of the edit controls', (tester) async {
        await pumpPreview(tester, scenario: 1);

        expect(find.text('Weekend errands'), findsWidgets);
        expect(find.byKey(const Key('expand_raw_notes_n24')), findsOneWidget);
        for (final id in ['n24', 'n23', 'n21']) {
          expect(find.byKey(Key('cluster_folder_dropdown_$id')), findsNothing);
          expect(find.byKey(Key('style_button_$id')), findsNothing);
          expect(find.byKey(Key('edit_text_button_$id')), findsNothing);
          expect(find.byKey(Key('merge_button_$id')), findsNothing);
          expect(find.byKey(Key('delete_cluster_$id')), findsNothing);
        }
        await tester.tap(find.byKey(const Key('expand_raw_notes_n24')));
        await tester.pumpAndSettle();
        expect(find.text('ORIGIN RAW NOTES (3)'), findsOneWidget);
        expect(find.text('Move Out'), findsNothing, reason: 'thoughts are only listed in Read mode');

        // A checklist ticks in Read mode.
        await reveal(tester, find.byKey(const Key('note_task_0')));
        await tester.tap(find.byKey(const Key('note_task_0')));
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(find.byKey(const Key('note_task_0'))).properties.checked, isTrue);
      });

      testWidgets('Edit mode: the action row, the style sheet, a hand-edited note and its confirmation', (tester) async {
        await pumpPreview(tester, scenario: 2);

        // Style: the production sheet; the choice shows the rewrite and a message.
        await tester.ensureVisible(find.byKey(const Key('style_button_n24')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('style_button_n24')));
        await tester.pumpAndSettle();
        expect(find.text('AI Style Re-Writer'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        await tester.tap(find.text('Key points'));
        await tester.pumpAndSettle();
        expect(find.text('Applying style "Key points" to #S-06...'), findsOneWidget);
        expect(find.text('Rewriting…'), findsWidgets);
        ScaffoldMessenger.of(tester.element(find.byType(SynthesisScreenPreview))).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        // The hand-edited note says so and shows it on its Style control.
        await reveal(tester, find.byKey(const Key('hand_edited_notice_n20')));
        expect(find.byKey(const Key('hand_edited_notice_n20')), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('style_button_n20')), matching: find.text('Edited by hand')),
            findsOneWidget);
        expect(find.byKey(const Key('hand_edited_notice_n24')), findsNothing);

        // A hand-edited note asks first; Cancel leaves it alone.
        await reveal(tester, find.byKey(const Key('style_button_n20')));
        await tester.tap(find.byKey(const Key('style_button_n20')));
        await tester.pumpAndSettle();
        expect(find.text('Rewriting in a style replaces your own edits to this note.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('rewrite_cancel_button')));
        await tester.pumpAndSettle();
        expect(find.text('AI Style Re-Writer'), findsNothing);
        await tester.tap(find.byKey(const Key('style_button_n20')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rewrite_confirm_button')));
        await tester.pumpAndSettle();
        expect(find.text('AI Style Re-Writer'), findsOneWidget);
      });

      testWidgets('Edit text: an empty text is refused, a text is saved and marks the note edited by hand', (tester) async {
        await pumpPreview(tester, scenario: 2);

        await tester.tap(find.byKey(const Key('edit_text_button_n24')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('note_text_field')), '   ');
        await tester.tap(find.byKey(const Key('note_text_save_button')));
        await tester.pumpAndSettle();
        expect(find.text('A note cannot be empty.'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('note_text_field')), '**My own title**\n\nMy own words.');
        await tester.tap(find.byKey(const Key('note_text_save_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('note_text_field')), findsNothing);
        expect(find.text('My own words.'), findsOneWidget);
        expect(find.byKey(const Key('hand_edited_notice_n24')), findsOneWidget);
      });

      testWidgets('single-thought guard, ejection and merge use the production sheets', (tester) async {
        await pumpPreview(tester, scenario: 2);

        // A note of three thoughts offers Move Out; open n22 (one thought) and see none.
        await tester.tap(find.byKey(const Key('expand_raw_notes_n24')));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Move Out').first);
        expect(find.text('Move Out'), findsNWidgets(3));
        await tester.tap(find.text('Move Out').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('Reassign Raw Note'), findsOneWidget);
        await tester.tap(find.byKey(const Key('ejection_make_independent_note_button')));
        await tester.pumpAndSettle();
        expect(find.text('Promoted [#01] to independent synthesized note.'), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(SynthesisScreenPreview))).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        // Merge n24 into n23.
        await tester.ensureVisible(find.byKey(const Key('merge_button_n24')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('merge_button_n24')));
        await tester.pumpAndSettle();
        expect(find.text('Merge Session #S-06'), findsOneWidget);
        await tester.tap(find.byKey(const Key('merge_target_n23')));
        await tester.pumpAndSettle();
        expect(find.text('Merged [#S-06] into #S-05'), findsOneWidget);
        expect(card('n24'), findsNothing, reason: 'consolidated into #S-05 and removed');
        expect(find.text('#S-06'), findsNothing);
      });

      testWidgets('folder panel scenario: panel open with counts, Manage folders, selection filters', (tester) async {
        await pumpPreview(tester, scenario: 3);

        expect(find.byKey(const Key('folder_panel')), findsOneWidget);
        expect(find.byKey(const Key('folder_panel_all_notes_count')), findsOneWidget);
        expect(find.byKey(const Key('folder_panel_row_Work_count')), findsOneWidget);
        expect(find.byKey(const Key('manage_folders_link')), findsOneWidget);

        await tester.tap(find.byKey(const Key('folder_panel_row_Journal')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('folder_panel')), findsNothing);
        expect(find.descendant(of: find.byKey(const Key('synthesis_folder_button')), matching: find.text('Journal')),
            findsOneWidget);
        expect(card('n22'), findsOneWidget);
        expect(card('n24'), findsNothing);

        await tester.tap(find.byKey(const Key('synthesis_folder_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('manage_folders_link')));
        await tester.pumpAndSettle();
        expect(find.text('Settings would open here.'), findsOneWidget);
      });

      testWidgets('every scenario renders with zero overflows and the chips switch scenario', (tester) async {
        for (var i = 0; i < 4; i++) {
          await pumpPreview(tester, scenario: i);
          expect(tester.takeException(), isNull, reason: 'scenario $i');
        }
        await pumpPreview(tester);
        await tester.tap(find.byKey(const Key('synthesis_scenario_3')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('folder_panel')), findsOneWidget);
        await tester.tap(find.byKey(const Key('synthesis_scenario_0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('folder_panel')), findsNothing);
      });
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
          find.textContaining('Verify capture widget on locked phone'),
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
      expect(find.textContaining('thoughts ready for Synthesis'), findsOneWidget);
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

      // Tap Settings gear button to open the Settings preview screen
      final settingsGear = find.byKey(const Key('settings_gear_button'));
      expect(settingsGear, findsOneWidget);
      await tester.tap(settingsGear);
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Settings & Diagnostics'), findsNothing);
      expect(find.text('Accessibility Interceptor'), findsNothing);
      expect(find.textContaining('Battery'), findsNothing);
      expect(find.byKey(const Key('synthesis_note_threshold_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('synthesis_inactivity_minutes_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('trigger_synthesis_now_btn')), findsOneWidget);

      // Folders come first, each with its description; calendar and raw-audio controls are gone.
      final folderHeaderFinder = find.text('FOLDERS');
      expect(folderHeaderFinder, findsOneWidget);
      expect(find.byKey(const Key('settings_folder_list')), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      expect(find.textContaining('how the speaker feels'), findsOneWidget);
      expect(find.byKey(const Key('add_custom_folder_button')), findsNothing);
      expect(find.text('CALENDAR SYNCHRONIZATION'), findsNothing);
      expect(find.text('AUDIO CAPTURE STORAGE'), findsNothing);
      expect(find.textContaining('DIAGNOSTIC LOGGING'), findsNothing);

      // Phone memory and permissions are collapsed until opened.
      await tester.scrollUntilVisible(find.byKey(const Key('settings_memory_header')), 300);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evict_models_btn')), findsNothing);
      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('Needs attention'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_memory_header')));
      await tester.pumpAndSettle();
      final evictBtnFinder = find.byKey(const Key('evict_models_btn'));
      await tester.scrollUntilVisible(evictBtnFinder, 300);
      await tester.pumpAndSettle();
      expect(evictBtnFinder, findsOneWidget);
      expect(find.text('Free model memory now'), findsOneWidget);
      expect(find.text('1.58 GB'), findsOneWidget);

      // The licences link sits at the very end.
      await tester.scrollUntilVisible(find.byKey(const Key('settings_licences_link')), 300);
      expect(find.text('Open-source licences'), findsOneWidget);

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

  group('ModelSetupPreview (FR16) on 360dp', () {
    Future<void> pumpScenario(WidgetTester tester, int scenario) async {
      tester.view.physicalSize = const Size(360 * 2, 1800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: ModelSetupPreview(initialScenario: scenario)));
      await tester.pumpAndSettle();
    }

    testWidgets('every scenario renders with zero overflows', (tester) async {
      for (var i = 0; i < 5; i++) {
        await pumpScenario(tester, i);
        expect(find.text('On-device models'), findsOneWidget, reason: 'scenario $i');
        expect(tester.takeException(), isNull, reason: 'scenario $i');
      }
    });

    testWidgets('nothing downloaded offers Download and the candidate carries a Testing tag', (tester) async {
      await pumpScenario(tester, 0);
      expect(find.text('Download'), findsNWidgets(3));
      expect(find.byKey(const Key('model_testing_tag_qwen3-1.7b')), findsOneWidget);
    });

    testWidgets('speech downloading shows 312 MB of 671 MB', (tester) async {
      await pumpScenario(tester, 1);
      expect(find.text('312 MB of 671 MB'), findsOneWidget);
    });

    testWidgets('4B ready and in use', (tester) async {
      await pumpScenario(tester, 2);
      expect(find.text('In use'), findsOneWidget);
      expect(find.byKey(const Key('model_download_qwen3-1.7b')), findsOneWidget);
    });

    testWidgets('a phone too small for the 4B greys it out but still offers the 1.7B', (tester) async {
      await pumpScenario(tester, 3);
      expect(find.text('Needs a phone with 8 GB of memory. This phone has 6 GB.'), findsOneWidget);
      expect(find.byKey(const Key('model_download_qwen3-4b')), findsNothing);
      expect(find.byKey(const Key('model_download_qwen3-1.7b')), findsOneWidget);
    });

    testWidgets('no model fits shows the honest message', (tester) async {
      await pumpScenario(tester, 4);
      expect(find.byKey(const Key('model_no_fit_message')), findsOneWidget);
    });

    testWidgets('mock buttons move the state and the scenario chips switch scenario', (tester) async {
      await pumpScenario(tester, 0);
      await tester.tap(find.byKey(const Key('model_download_qwen3-4b')));
      await tester.pump();
      expect(find.byKey(const Key('model_progress_qwen3-4b')), findsOneWidget);
      await tester.tap(find.byKey(const Key('model_cancel_qwen3-4b')));
      await tester.pump();
      expect(find.byKey(const Key('model_download_qwen3-4b')), findsOneWidget);

      await tester.tap(find.byKey(const Key('model_scenario_4')));
      await tester.pump();
      expect(find.byKey(const Key('model_no_fit_message')), findsOneWidget);
    });

    testWidgets('reachable from the settings preview', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 1800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: GalleryShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_gear_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_models_row')));
      await tester.pumpAndSettle();
      expect(find.text('On-device models'), findsOneWidget);
    });
  });
}
