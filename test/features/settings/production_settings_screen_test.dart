import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/settings/model_credits.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

import 'settings_test_harness.dart';

void main() {
  setUp(mockHardwareChannel);

  group('Production SettingsScreen', () {
    testWidgets('sections run in priority order on a 360dp phone with no overflow', (tester) async {
      await pumpSettingsScreen(tester, height: 4000);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Settings & Diagnostics'), findsNothing);
      expect(find.byKey(const Key('settings_back_button')), findsOneWidget);

      double top(Finder finder) {
        expect(finder, findsOneWidget);
        return tester.getTopLeft(finder).dy;
      }

      final order = [
        top(find.text('FOLDERS')),
        top(find.text('AUTOMATIC SYNTHESIS')),
        top(find.text('ON-DEVICE MODELS')),
        top(find.text('CAPTURE')),
        top(find.text('PHONE MEMORY AND TEMPERATURE')),
        top(find.text('PERMISSIONS')),
        top(find.byKey(const Key('settings_licences_link'))),
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(order.toSet().length, order.length);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Automatic Synthesis keeps its controls and wording', (tester) async {
      final notes = NotesRepository();
      await notes.saveNote(Note(
        rawText: 'Buffered note',
        correctedText: 'Buffered note',
        state: ThoughtState.processed,
      ));
      await pumpSettingsScreen(tester, height: 3000, notes: notes);

      for (final text in const [
        'AUTOMATIC SYNTHESIS',
        'Synthesis turns waiting thoughts into notes by itself. Choose when it starts.',
        'Start after this many thoughts',
        'Synthesis starts once this many thoughts are waiting.',
        'Or after a quiet period',
        'Synthesis also starts when no new thought has arrived for this long.',
        '1 thought ready for Synthesis',
        'Synthesize Now',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.textContaining('Trigger After'), findsNothing);
      expect(find.byKey(const Key('synthesis_note_threshold_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('synthesis_inactivity_minutes_dropdown')), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byKey(const Key('synthesize_buffer_now_button')));
      expect(button.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Synthesize Now shows Synthesizing… and is disabled while a run is going', (tester) async {
      final notes = NotesRepository();
      await notes.saveNote(Note(
        rawText: 'Buffered note',
        correctedText: 'Buffered note',
        state: ThoughtState.processed,
      ));
      final container = await pumpSettingsScreen(tester, height: 3000, notes: notes);
      final buttonFinder = find.byKey(const Key('synthesize_buffer_now_button'));
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);

      container.read(synthesisRunningProvider.notifier).setRunning(true);
      await tester.pump();

      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNull);
      expect(find.descendant(of: buttonFinder, matching: find.text('Synthesizing…')), findsOneWidget);
      expect(find.descendant(of: buttonFinder, matching: find.byType(ThinkingIndicator)), findsOneWidget);
      expect(find.text('Synthesize Now'), findsNothing);
      expect(tester.takeException(), isNull);

      container.read(synthesisRunningProvider.notifier).setRunning(false);
      await tester.pump();
      expect(find.text('Synthesize Now'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(buttonFinder).onPressed, isNotNull);
      await unmountScreen(tester);
    });

    testWidgets('controls that did nothing and the diagnostic logging section are gone', (tester) async {
      await pumpSettingsScreen(tester, height: 4000);
      await expandSection(tester, 'settings_memory_header');
      await expandSection(tester, 'settings_permissions_header');

      expect(find.text('CALENDAR SYNCHRONIZATION'), findsNothing);
      expect(find.textContaining('Calendar'), findsNothing);
      expect(find.text('AUDIO CAPTURE STORAGE'), findsNothing);
      expect(find.textContaining('Keep Raw Audio'), findsNothing);
      expect(find.textContaining('Next refresh'), findsNothing);

      expect(find.textContaining('DIAGNOSTIC LOGGING'), findsNothing);
      expect(find.byKey(const Key('view_system_logs_button')), findsNothing);
      expect(find.byKey(const Key('copy_log_dump_button')), findsNothing);
      expect(find.byKey(const Key('clear_logs_button')), findsNothing);
      expect(find.text('View System Logs'), findsNothing);
      expect(find.text('ABOUT'), findsNothing);
      expect(find.text('Licences and credits'), findsNothing);
    });

    testWidgets('Free model memory now shows a confirmation SnackBar without the word evicted', (tester) async {
      await pumpSettingsScreen(tester, height: 3000);
      await expandSection(tester, 'settings_memory_header');

      final button = find.byKey(const Key('evict_models_button'));
      expect(find.descendant(of: button, matching: find.text('Free model memory now')), findsOneWidget);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('AI model memory freed.'), findsOneWidget);
      expect(find.textContaining('evicted'), findsNothing);
      // No fabricated memory figures.
      expect(find.textContaining('1.58 GB'), findsNothing);
      await unmountScreen(tester);
    });

    testWidgets('Capture section has the home-screen widget row and the background switch', (tester) async {
      await pumpSettingsScreen(tester, height: 3000);

      expect(find.text('CAPTURE'), findsOneWidget);
      expect(find.text('Add capture widget to home screen'), findsOneWidget);
      expect(find.text('Keep capture ready in the background'), findsOneWidget);
      expect(
        find.text(
            'Keeps the Record button on your lock screen and finishes transcription and notes while the app is closed.'),
        findsOneWidget,
      );
      expect(find.text('Keep App Alive in Background'), findsNothing);
      expect(find.textContaining('foreground service'), findsNothing);
      // The switch is visible without opening Permissions (the NOTES section has a switch of its own).
      expect(find.widgetWithText(SwitchListTile, 'Keep capture ready in the background'), findsOneWidget);
    });

    testWidgets('Open-source licences link opens the licence page with the model credits', (tester) async {
      registerModelCredits();
      await pumpSettingsScreen(tester, height: 3000);

      final link = find.byKey(const Key('settings_licences_link'));
      expect(find.text('Open-source licences'), findsOneWidget);
      // A small link, not a card row.
      expect(find.descendant(of: find.byType(ListTile), matching: find.text('Open-source licences')), findsNothing);
      final text = tester.widget<Text>(find.text('Open-source licences'));
      expect(text.style!.fontSize, inInclusiveRange(12, 13));

      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('Eudemonia'), findsWidgets);
      for (final credit in modelCredits) {
        expect(find.textContaining(credit.package), findsWidgets);
      }
    });
  });
}
