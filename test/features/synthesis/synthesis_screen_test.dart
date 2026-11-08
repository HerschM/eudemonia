import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

void main() {
  group('SynthesisScreen Widget & Contract Tests', () {
    testWidgets(
      'renders compact dual dropdown filters, batch banner, and cluster cards on 360dp narrow viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final initialClusters = [
          SynthesisCluster(
            clusterId: 'cluster_1',
            sequenceNumber: '#S-01',
            folder: 'Work',
            synthesizedContent:
                'Refined architectural blueprint for foreground services and hardware button routing.',
            sessionStart: DateTime.now().subtract(const Duration(minutes: 30)),
            sessionEnd: DateTime.now(),
            sessionDuration: const Duration(minutes: 30),
            originNotes: [
              SynthesisOriginNote(
                id: 1,
                formattedSequence: '#01',
                cleanedText: 'Need to implement foreground keep-alive service',
                folder: 'Work',
                timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
              ),
              SynthesisOriginNote(
                id: 2,
                formattedSequence: '#02',
                cleanedText: 'Add notification start and stop buttons',
                folder: 'Work',
                timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
              ),
            ],
            isUnread: true,
            isActionExtracted: true,
          ),
          SynthesisCluster(
            clusterId: 'cluster_2',
            sequenceNumber: '#S-02',
            folder: 'Ideas',
            synthesizedContent: 'Voice-first cognitive thought capture ideas.',
            sessionStart: DateTime.now().subtract(const Duration(hours: 1)),
            sessionEnd: DateTime.now().subtract(const Duration(minutes: 45)),
            sessionDuration: const Duration(minutes: 15),
            originNotes: [
              SynthesisOriginNote(
                id: 3,
                formattedSequence: '#03',
                cleanedText: 'Single origin note in this session',
                folder: 'Ideas',
                timestamp:
                    DateTime.now().subtract(const Duration(minutes: 50)),
              ),
            ],
            isUnread: false,
            isActionExtracted: false,
          ),
        ];

        final mockNotesRepo = NotesRepository();
        await mockNotesRepo.saveNote(Note(
          rawText: 'Raw unprocessed thought',
          correctedText: 'Raw unprocessed thought',
          state: ThoughtState.processed,
        ));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(mockNotesRepo),
              synthesisRepositoryProvider.overrideWith(
                () => SynthesisRepository(initialClusters),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SynthesisScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Title and Dual Filters
        expect(find.text('SYNTHESIS SESSIONS'), findsOneWidget);
        expect(find.byKey(const Key('synthesis_triage_filter_dropdown')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_folder_filter_dropdown')),
            findsOneWidget);

        // 2. Pending Batch Synthesis Banner
        expect(
            find.byKey(const Key('pending_synthesis_batch_banner')), findsOneWidget);
        expect(find.textContaining('1 raw thoughts ready to cluster'),
            findsOneWidget);
        expect(find.byKey(const Key('synthesize_now_banner_button')),
            findsOneWidget);

        // 3. Cluster Cards
        expect(find.byKey(const Key('synthesis_cluster_card_#S-01')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_cluster_card_#S-02')),
            findsOneWidget);

        // 4. Header elements: Sequence number, unread dot, style, merge
        expect(find.text('#S-01'), findsOneWidget);
        expect(find.byKey(const Key('unread_dot_#S-01')), findsOneWidget);
        expect(find.byKey(const Key('style_button_#S-01')), findsOneWidget);
        expect(find.byKey(const Key('merge_button_#S-01')), findsOneWidget);

        // 5. Expandable Raw Notes Pill
        final expandPill = find.byKey(const Key('expand_raw_notes_#S-01'));
        expect(expandPill, findsOneWidget);
        expect(find.text('2 Raw Notes'), findsOneWidget);

        // Tap to expand
        await tester.tap(expandPill);
        await tester.pumpAndSettle();

        // Verified origin notes are shown
        expect(find.text('ORIGIN RAW NOTES (2)'), findsOneWidget);
        expect(find.text('#01'), findsOneWidget);
        expect(find.text('#02'), findsOneWidget);

        // Multi-note cluster has [Move Out] buttons
        expect(find.byKey(const Key('move_out_note_1')), findsOneWidget);
        expect(find.byKey(const Key('move_out_note_2')), findsOneWidget);

        // Single Note Guard: Cluster #S-02 has only 1 origin note
        final expandPill2 = find.byKey(const Key('expand_raw_notes_#S-02'));
        await tester.scrollUntilVisible(expandPill2, 100,
            scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(expandPill2);
        await tester.pumpAndSettle();
        await tester.tap(expandPill2);
        await tester.pumpAndSettle();

        expect(find.text('1 Raw Notes'), findsOneWidget);
        // [Move Out] must be hidden for 1-note cluster to prevent orphaned sessions
        expect(find.byKey(const Key('move_out_note_3')), findsNothing);
      },
    );

    testWidgets(
      'Filter dropdowns correctly filter clusters by folder and triage status',
      (WidgetTester tester) async {
        final clusters = [
          SynthesisCluster(
            clusterId: 'cluster_work',
            sequenceNumber: '#S-01',
            folder: 'Work',
            synthesizedContent: 'Work cluster content',
            sessionStart: DateTime.now(),
            sessionEnd: DateTime.now(),
            sessionDuration: const Duration(minutes: 10),
            originNotes: const [],
            isUnread: true,
          ),
          SynthesisCluster(
            clusterId: 'cluster_ideas',
            sequenceNumber: '#S-02',
            folder: 'Ideas',
            synthesizedContent: 'Ideas cluster content',
            sessionStart: DateTime.now(),
            sessionEnd: DateTime.now(),
            sessionDuration: const Duration(minutes: 10),
            originNotes: const [],
            isUnread: false,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              synthesisRepositoryProvider.overrideWith(
                () => SynthesisRepository(clusters),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SynthesisScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both clusters visible initially
        expect(find.byKey(const Key('synthesis_cluster_card_#S-01')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_cluster_card_#S-02')),
            findsOneWidget);

        // Filter by Triage: Unread
        await tester.tap(find.byKey(const Key('synthesis_triage_filter_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unread').last);
        await tester.pumpAndSettle();

        // Only #S-01 is unread
        expect(find.byKey(const Key('synthesis_cluster_card_#S-01')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_cluster_card_#S-02')),
            findsNothing);
      },
    );

    testWidgets(
      'Empty state is shown when no synthesis clusters exist',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              synthesisRepositoryProvider.overrideWith(
                () => SynthesisRepository([]),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SynthesisScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No synthesis sessions yet'), findsOneWidget);
        expect(
          find.text(
              'Thoughts captured in close proximity or sharing similar context will be automatically clustered here.'),
          findsOneWidget,
        );
      },
    );
  });
}
