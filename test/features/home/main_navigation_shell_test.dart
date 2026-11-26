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
import 'package:eudemonia/features/settings/background_permission_service.dart';
import '../settings/fake_permission_gateway.dart';

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

  group('MainNavigationShell 2-Stage UX & Pipeline HUD Tests', () {
    testWidgets(
      'Capture badge ignores thoughts already consumed by a synthesis session',
      (WidgetTester tester) async {
        final notesRepo = NotesRepository();
        await notesRepo.saveNote(Note(correctedText: 'Fresh', state: ThoughtState.processed));
        await notesRepo.saveNote(Note(correctedText: 'Clubbed', state: ThoughtState.synthesized));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [notesRepositoryProvider.overrideWithValue(notesRepo)],
            child: const MaterialApp(home: MainNavigationShell()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Capture (1)'), findsOneWidget);
      },
    );

    testWidgets(
      'MainNavigationShell renders branding, HUD pill, and two stage tabs with zero-suppression on 360dp narrow viewport',
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

        // A pending thought card renders an endlessly animating VoiceWaveIndicator.
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

        // 5. Exactly two stages, each half the bar, and no overflow at 360dp
        expect(find.byType(Tab), findsNWidgets(2));
        expect(find.text('Insights'), findsNothing);
        expect(find.text('Action'), findsNothing);
        // Each stage owns half of the bar: label centres sit at 1/4 and 3/4 of its width
        final bar = tester.getRect(find.byType(TabBar));
        final captureX = tester.getCenter(find.widgetWithText(Tab, 'Capture (3)')).dx;
        final synthesisX = tester.getCenter(find.widgetWithText(Tab, 'Synthesis (1)')).dx;
        expect(captureX, closeTo(bar.left + bar.width * 0.25, 2));
        expect(synthesisX, closeTo(bar.left + bar.width * 0.75, 2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tapping a stage tab switches stages; zero counts show clean labels',
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

        // Initially on Capture; zero-suppressed labels carry no count
        expect(find.text('Capture'), findsOneWidget);
        expect(find.text('Synthesis'), findsOneWidget);
        expect(find.text('SYNTHESIS SESSIONS'), findsNothing);

        await tester.tap(find.text('Synthesis'));
        await tester.pumpAndSettle();
        expect(find.text('SYNTHESIS SESSIONS'), findsOneWidget);

        await tester.tap(find.text('Capture'));
        await tester.pumpAndSettle();
        expect(find.text('SYNTHESIS SESSIONS'), findsNothing);
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
        expect(find.textContaining('Insights'), findsNothing);
        expect(find.textContaining('Action'), findsNothing);
        expect(find.textContaining('Stage 3'), findsNothing);
        expect(find.textContaining('Stage 4'), findsNothing);

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
          ProviderScope(
            overrides: [
              runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
            ],
            child: const MaterialApp(
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
