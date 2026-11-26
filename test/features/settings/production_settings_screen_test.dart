import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/settings/model_credits.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

import 'fake_permission_gateway.dart';

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
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
      'renders Automatic Synthesis thresholds, folders, RAM telemetry, logs and About on 360dp narrow viewport',
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
              runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
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

        // 2. Automatic Synthesis section, in plain words
        final synthHeader = find.text('AUTOMATIC SYNTHESIS');
        await tester.scrollUntilVisible(synthHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(synthHeader, findsOneWidget);
        for (final text in const [
          'Synthesis turns waiting thoughts into notes by itself. Choose when it starts.',
          'Start after this many thoughts',
          'Synthesis starts once this many thoughts are waiting.',
          'Or after a quiet period',
          'Synthesis also starts when no new thought has arrived for this long.',
        ]) {
          await tester.scrollUntilVisible(find.text(text), 100,
              scrollable: find.byType(Scrollable).first);
          expect(find.text(text), findsOneWidget);
        }
        expect(find.textContaining('Trigger After'), findsNothing);
        expect(find.text('AUTOMATIC SYNTHESIS TRIGGER & BATCHING'), findsNothing);

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
        expect(find.text('1 thought ready for Synthesis'), findsOneWidget);

        // 3. Folders: a read-only list of the real default folders, nothing editable
        final folderHeader = find.text('FOLDERS');
        await tester.scrollUntilVisible(folderHeader, 100,
            scrollable: find.byType(Scrollable).first);
        expect(folderHeader, findsOneWidget);
        final folderList = find.byKey(const Key('settings_folder_list'));
        for (final folder in defaultFolders) {
          expect(find.descendant(of: folderList, matching: find.text(folder.name)), findsOneWidget);
        }
        expect(find.byKey(const Key('add_custom_folder_button')), findsNothing);
        expect(find.text('Ideas'), findsNothing);
        expect(find.text('Todos'), findsNothing);

        // 4. Controls that did nothing are gone
        expect(find.text('CALENDAR SYNCHRONIZATION'), findsNothing);
        expect(find.textContaining('Calendar'), findsNothing);
        expect(find.text('AUDIO CAPTURE STORAGE'), findsNothing);
        expect(find.textContaining('Keep Raw Audio'), findsNothing);
        expect(find.textContaining('Next refresh'), findsNothing);

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

        // 7. About
        await tester.scrollUntilVisible(find.text('ABOUT'), 100,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.text('Licences and credits'), findsOneWidget);
        expect(tester.takeException(), isNull);
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
          ProviderScope(
            overrides: [
              runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
            ],
            child: const MaterialApp(
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

        expect(find.text('AI models evicted from memory.'), findsOneWidget);
        // No fabricated memory figures.
        expect(find.textContaining('1.58 GB'), findsNothing);
      },
    );

    testWidgets(
      'background capture row uses plain wording',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Keep capture ready in the background'), findsOneWidget);
        expect(
          find.text(
              'Keeps the Record button on your lock screen and finishes transcription and notes while the app is closed.'),
          findsOneWidget,
        );
        expect(find.text('Keep App Alive in Background'), findsNothing);
        expect(find.textContaining('foreground service'), findsNothing);
      },
    );

    testWidgets(
      'Licences and credits row opens the licence page with the model credits',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        registerModelCredits();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(const Key('settings_licences_row'));
        await tester.scrollUntilVisible(row, 100, scrollable: find.byType(Scrollable).first);
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.byType(LicensePage), findsOneWidget);
        expect(find.text('Eudemonia'), findsWidgets);
        for (final credit in modelCredits) {
          expect(find.textContaining(credit.package), findsWidgets);
        }
      },
    );
  });
}
