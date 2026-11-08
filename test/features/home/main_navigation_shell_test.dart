import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/settings/settings_screen.dart';

import 'package:flutter/services.dart';

class FakePendingQueueCountNotifier extends PendingQueueCountNotifier {
  final int initial;
  FakePendingQueueCountNotifier(this.initial);

  @override
  int build() => initial;
}

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

  group('MainNavigationShell 4-Stage UX & Pipeline HUD Tests', () {
    testWidgets(
      'MainNavigationShell renders branding, HUD pill, and 4-stage tabs with zero-suppression on 360dp narrow viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockNotesRepo = NotesRepository();
        await mockNotesRepo.saveNote(Note(
          rawText: 'Test note 1',
          correctedText: 'Test note 1',
          isRead: false,
          state: ThoughtState.processed,
        ));
        await mockNotesRepo.saveNote(Note(
          rawText: 'Test note 2',
          correctedText: 'Test note 2',
          isRead: false,
          state: ThoughtState.processed,
        ));

        final initialClusters = [
          SynthesisCluster(
            clusterId: 'cluster_test_1',
            sequenceNumber: '#S-01',
            folder: 'Ideas',
            synthesizedContent: 'Synthesized cluster content',
            sessionStart: DateTime.now().subtract(const Duration(minutes: 20)),
            sessionEnd: DateTime.now(),
            sessionDuration: const Duration(minutes: 20),
            originNotes: const [],
            isUnread: true,
            isActionExtracted: true,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(mockNotesRepo),
              synthesisRepositoryProvider.overrideWith(
                () => SynthesisRepository(initialClusters),
              ),
              pendingQueueCountProvider.overrideWith(
                () => FakePendingQueueCountNotifier(1),
              ),
            ],
            child: const MaterialApp(
              home: MainNavigationShell(),
            ),
          ),
        );

        // HomeScreen renders SmoothProcessingIndicator (infinite repeat animation) when pendingQueueCount > 0.
        // Use pump with finite duration instead of pumpAndSettle to avoid timeout.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. App Branding
        expect(find.text('Eudemonia'), findsOneWidget);

        // 2. Settings button
        expect(find.byKey(const Key('settings_gear_button')), findsOneWidget);

        // 3. Pipeline HUD Pill shows active pending count
        expect(find.byKey(const Key('top_ai_pipeline_pill')), findsOneWidget);
        // Total pending = 1 (queue) + 2 (processed notes ready to cluster) = 3
        expect(find.textContaining('in Pipeline ▾'), findsOneWidget);

        // 4. Tab Zero-Suppression Rules
        // Capture has 2 unread notes + 1 queue item = 3
        expect(find.text('Capture (3)'), findsOneWidget);
        // Synthesis has 1 unread cluster = 1
        expect(find.text('Synthesis (1)'), findsOneWidget);
        // Insights and Action show clean labels without zero
        expect(find.text('Insights'), findsOneWidget);
        expect(find.text('Action'), findsOneWidget);

        // 5. Insights and Action are greyed out (Opacity 0.38)
        final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
        expect(opacities.any((o) => o.opacity == 0.38), isTrue);
      },
    );

    testWidgets(
      'Tapping Insights or Action does NOT switch tab (unclickable placeholders)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              synthesisRepositoryProvider.overrideWith(
                () => SynthesisRepository([]),
              ),
            ],
            child: const MaterialApp(
              home: MainNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially on Capture tab (shows capture floating trigger or capture feed)
        expect(find.text('Capture'), findsOneWidget);

        // Tap Insights tab
        await tester.tap(find.text('Insights'));
        await tester.pumpAndSettle();

        // Must still NOT navigate to Insights body
        expect(find.text('Stage 3: Insights'), findsNothing);

        // Tap Action tab
        await tester.tap(find.text('Action'));
        await tester.pumpAndSettle();

        // Must still NOT navigate to Action body
        expect(find.text('Stage 4: Action Engine'), findsNothing);

        // Tap Synthesis tab
        await tester.tap(find.text('Synthesis'));
        await tester.pumpAndSettle();

        // Navigates to Synthesis screen successfully
        expect(find.text('SYNTHESIS SESSIONS'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Pipeline HUD pill opens modal and triggers Synthesize Now',
      (WidgetTester tester) async {
        final mockNotesRepo = NotesRepository();
        await mockNotesRepo.saveNote(Note(
          rawText: 'Unclustered note',
          correctedText: 'Unclustered note',
          state: ThoughtState.processed,
        ));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(mockNotesRepo),
              pendingQueueCountProvider.overrideWith(
                () => FakePendingQueueCountNotifier(0),
              ),
            ],
            child: const MaterialApp(
              home: MainNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap HUD pill
        await tester.tap(find.byKey(const Key('top_ai_pipeline_pill')));
        await tester.pumpAndSettle();

        // HUD modal is shown
        expect(find.text('Mind Pipeline Status'), findsOneWidget);
        expect(find.text('Stage 1: Capture'), findsOneWidget);
        expect(find.text('Stage 2: Synthesis'), findsOneWidget);

        // Tap Synthesize Now in modal
        final synthBtn = find.byKey(const Key('hud_synthesize_now_button'));
        expect(synthBtn, findsOneWidget);
        await tester.tap(synthBtn);
        await tester.pumpAndSettle();

        // Modal closed
        expect(find.text('Mind Pipeline Status'), findsNothing);
      },
    );

    testWidgets(
      'Tapping Settings button navigates to SettingsScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: MainNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap settings gear
        await tester.tap(find.byKey(const Key('settings_gear_button')));
        await tester.pumpAndSettle();

        // Settings screen opened
        expect(find.text('Settings & Diagnostics'), findsOneWidget);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );
  });
}
