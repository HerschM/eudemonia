import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'isAccessibilityServiceEnabled':
          return true;
        case 'isIgnoringBatteryOptimizations':
          return true;
        case 'isForegroundServiceRunning':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Production SettingsScreen New Sections & Controls Tests', () {
    testWidgets(
      'renders Automatic Synthesis batching thresholds, RAM telemetry, folder manifestos, and logs on 360dp narrow viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockNotesRepo = NotesRepository();
        await mockNotesRepo.saveNote(Note(
          rawText: 'Buffered note',
          correctedText: 'Buffered note',
          state: ThoughtState.processed,
        ));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(mockNotesRepo),
            ],
            child: const MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Settings & Diagnostics title and back button
        expect(find.text('Settings & Diagnostics'), findsOneWidget);
        expect(find.byKey(const Key('settings_back_button')), findsOneWidget);

        // 2. Automatic Synthesis Trigger & Batching Section
        final synthHeader = find.text('AUTOMATIC SYNTHESIS TRIGGER & BATCHING');
        await tester.scrollUntilVisible(synthHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(synthHeader, findsOneWidget);

        final noteThreshold =
            find.byKey(const Key('synthesis_note_threshold_dropdown'));
        await tester.scrollUntilVisible(noteThreshold, 100,
            scrollable: find.byType(Scrollable).first);
        expect(noteThreshold, findsOneWidget);

        final inactivityMinutes =
            find.byKey(const Key('synthesis_inactivity_minutes_dropdown'));
        await tester.scrollUntilVisible(inactivityMinutes, 100,
            scrollable: find.byType(Scrollable).first);
        expect(inactivityMinutes, findsOneWidget);

        final synthBufferBtn =
            find.byKey(const Key('synthesize_buffer_now_button'));
        await tester.scrollUntilVisible(synthBufferBtn, 100,
            scrollable: find.byType(Scrollable).first);
        expect(synthBufferBtn, findsOneWidget);

        // 3. Folder Management & Semantic Manifestos
        final folderHeader = find.text('FOLDER MANAGEMENT & SEMANTIC MANIFESTOS');
        await tester.scrollUntilVisible(folderHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(folderHeader, findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Ideas'), findsOneWidget);

        final addCustomFolderBtn =
            find.byKey(const Key('add_custom_folder_button'));
        await tester.scrollUntilVisible(addCustomFolderBtn, 100,
            scrollable: find.byType(Scrollable).first);
        expect(addCustomFolderBtn, findsOneWidget);

        // 4. Calendar Synchronization
        final calHeader = find.text('CALENDAR SYNCHRONIZATION');
        await tester.scrollUntilVisible(calHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(calHeader, findsOneWidget);
        expect(find.text('Sync Action Items with Calendar'), findsOneWidget);

        // 5. On-Device AI Memory & Thermal Gating
        final memHeader = find.text('ON-DEVICE AI MEMORY & THERMAL GATING');
        await tester.scrollUntilVisible(memHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(memHeader, findsOneWidget);
        expect(find.text('Thermal Headroom'), findsOneWidget);

        final evictBtn = find.byKey(const Key('evict_models_button'));
        await tester.scrollUntilVisible(evictBtn, 100,
            scrollable: find.byType(Scrollable).first);
        expect(evictBtn, findsOneWidget);

        // 6. Diagnostic Logging (2MB Rotating)
        final logHeader = find.text('DIAGNOSTIC LOGGING (2MB ROTATING)');
        await tester.scrollUntilVisible(logHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(logHeader, findsOneWidget);

        final viewLogsBtn = find.byKey(const Key('view_system_logs_button'));
        await tester.scrollUntilVisible(viewLogsBtn, 100,
            scrollable: find.byType(Scrollable).first);
        expect(viewLogsBtn, findsOneWidget);
        expect(find.byKey(const Key('copy_log_dump_button')), findsOneWidget);
        expect(find.byKey(const Key('clear_logs_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Evict Models button displays confirmation SnackBar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final evictBtn = find.byKey(const Key('evict_models_button'));
        await tester.scrollUntilVisible(evictBtn, 100,
            scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(evictBtn);
        await tester.pumpAndSettle();
        await tester.tap(evictBtn);
        await tester.pumpAndSettle();

        expect(
            find.textContaining(
                'Memory reclaimed: ~1.58 GB RAM. Baseline: <60 MB.'),
            findsOneWidget);
      },
    );

    testWidgets(
      'Add Custom Folder dialog creates and displays custom folder',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final addBtn = find.byKey(const Key('add_custom_folder_button'));
        await tester.scrollUntilVisible(addBtn, 100,
            scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(addBtn);
        await tester.pumpAndSettle();
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.text('Add Custom Folder'), findsWidgets);

        await tester.enterText(
            find.byKey(const Key('new_folder_name_field')), 'Health & Wellness');
        await tester.enterText(
            find.byKey(const Key('new_folder_desc_field')), 'Workouts and sleep tracker.');
        await tester.tap(find.byKey(const Key('confirm_add_folder_button')));
        await tester.pumpAndSettle();

        expect(find.text('Health & Wellness'), findsOneWidget);
      },
    );
  });
}
