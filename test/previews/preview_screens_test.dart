import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../previews/gallery_shell.dart';
import '../../previews/screens/capture_screen_preview.dart';
import '../../previews/screens/synthesis_screen_preview.dart';
import '../../previews/screens/insights_screen_preview.dart';
import '../../previews/screens/action_screen_preview.dart';

void main() {
  group('Four-Stage Preview Screens Widget Tests', () {
    testWidgets('CaptureScreenPreview renders with strict header order and date-time format', (tester) async {
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
      expect(find.text('#04'), findsOneWidget);
      expect(find.text('#03'), findsOneWidget);
      expect(find.text('#01'), findsOneWidget);

      // Verify date-time format: DD/MM  HH:MM AM/PM
      expect(find.textContaining(RegExp(r'\d{2}/\d{2}\s\s\d{2}:\d{2}\s[AP]M')), findsWidgets);

      // Verify Header ordering: # Number before Play Button before Unread Dot before Delete
      // Check for first note (#04)
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

      // Note #03 is read -> unread dot should not be visible or present
      expect(find.byKey(const Key('unread_dot_note_3')), findsNothing);

      // Tapping "Style" button opens AI Style Re-Writer Sheet
      final styleButtonFinder = find.byKey(const Key('style_button_note_4'));
      expect(styleButtonFinder, findsOneWidget);
      await tester.tap(styleButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('AI Style Re-Writer'), findsOneWidget);
      expect(find.text('Concise & Direct'), findsOneWidget);
      expect(find.text('Bullet Points'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
    });

    testWidgets('SynthesisScreenPreview renders compact folder filter dropdown and expandable origin notes', (tester) async {
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

      // Expand origin raw notes pill
      final expandPillFinder = find.byKey(const Key('expand_origin_pill_S-02'));
      expect(expandPillFinder, findsOneWidget);
      await tester.tap(expandPillFinder);
      await tester.pumpAndSettle();

      // Verify origin notes rendered inside drawer
      expect(find.textContaining('Idea about splitting raw & processed'), findsOneWidget);

      // Tap Move Out button to open ejection modal
      final moveOutFinder = find.byKey(const Key('move_out_button_raw_1'));
      expect(moveOutFinder, findsOneWidget);
      await tester.tap(moveOutFinder);
      await tester.pumpAndSettle();

      expect(find.text('Reassign Raw Note [#01]'), findsOneWidget);
      expect(find.text('Move to Another Clubbed Note'), findsOneWidget);
      expect(find.text('Make It An Independent Note'), findsOneWidget);
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
