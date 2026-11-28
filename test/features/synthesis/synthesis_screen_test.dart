import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/synthesis/application/folder_settings.dart';
import 'package:eudemonia/features/synthesis/domain/folder_definition.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';

import 'notes_view_test_support.dart';

class _StoredFolders implements FolderStore {
  final List<FolderDefinition> folders;
  _StoredFolders(this.folders);

  @override
  Future<List<FolderDefinition>?> load() async => folders;

  @override
  Future<void> save(List<FolderDefinition> folders) async {}
}

void main() {
  group('SynthesisScreen Widget & Contract Tests', () {
    testWidgets('batch banner appears when a thought is saved while the screen is mounted', (tester) async {
      final repoHolder = <NotesRepository>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              repoHolder.add(ref.read(notesRepositoryProvider));
              return const MaterialApp(home: Scaffold(body: SynthesisScreen()));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pending_synthesis_batch_banner')), findsNothing);

      // Saved through the repository only: no manual invalidation anywhere.
      await tester.runAsync(() => repoHolder.first.saveNote(Note(
            correctedText: 'A fresh thought',
            state: ThoughtState.processed,
          )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_synthesis_batch_banner')), findsOneWidget);
      expect(find.text('1 thought ready for Synthesis'), findsOneWidget);
    });

    testWidgets(
      'renders the bar, the folder panel filters, batch banner, and cluster cards on 360dp narrow viewport',
      (WidgetTester tester) async {
        // Taller than a phone: the test font is wide, so an opened row's whole title takes many lines.
        tester.view.physicalSize = const Size(360, 1400);
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
                timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
              ),
              SynthesisOriginNote(
                id: 2,
                formattedSequence: '#02',
                cleanedText: 'Add notification start and stop buttons',
                timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
              ),
            ],
            isUnread: true,
            isActionExtracted: true,
          ),
          SynthesisCluster(
            clusterId: 'cluster_2',
            sequenceNumber: '#S-02',
            folder: 'Personal',
            synthesizedContent: 'Voice-first cognitive thought capture ideas.',
            sessionStart: DateTime.now().subtract(const Duration(hours: 1)),
            sessionEnd: DateTime.now().subtract(const Duration(minutes: 45)),
            sessionDuration: const Duration(minutes: 15),
            originNotes: [
              SynthesisOriginNote(
                id: 3,
                formattedSequence: '#03',
                cleanedText: 'Single origin note in this session',
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
              notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore(openEditPrefs)),
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

        // 1. The bar (the header and the two dropdowns moved into it and the folder panel)
        expect(find.text('SYNTHESIS SESSIONS'), findsNothing);
        expect(find.byKey(const Key('synthesis_folder_button')), findsOneWidget);
        expect(find.byKey(const Key('synthesis_mode_toggle')), findsOneWidget);
        expect(find.byKey(const Key('synthesis_expand_all_toggle')), findsOneWidget);
        await tester.tap(find.byKey(const Key('synthesis_folder_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('triage_chip_unread')), findsOneWidget);
        expect(find.byKey(const Key('folder_panel_row_Work')), findsOneWidget);
        // The panel covers 80 % of the width; the scrim is what is left of the list on its right.
        await tester.tapAt(const Offset(350, 500));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('folder_panel')), findsNothing);

        // 2. Pending Batch Synthesis Banner
        expect(
            find.byKey(const Key('pending_synthesis_batch_banner')), findsOneWidget);
        expect(find.text('1 thought ready for Synthesis'), findsOneWidget);
        expect(find.textContaining('🧩'), findsNothing);
        expect(find.byKey(const Key('synthesize_now_banner_button')),
            findsOneWidget);

        // 3. Cluster Cards
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_1')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_2')),
            findsOneWidget);

        // 4. Header elements: Sequence number, unread dot, style, merge
        expect(find.text('#S-01'), findsOneWidget);
        expect(find.byKey(const Key('unread_dot_cluster_1')), findsOneWidget);
        expect(find.byKey(const Key('style_button_cluster_1')), findsOneWidget);
        expect(find.byKey(const Key('merge_button_cluster_1')), findsOneWidget);

        // 5. Expandable raw thoughts link
        final expandPill = find.byKey(const Key('expand_raw_notes_cluster_1'));
        expect(expandPill, findsOneWidget);
        expect(find.text('From 2 thoughts'), findsOneWidget);

        // Tap to expand (sessions of one day are listed highest number first, so #S-01 is lower down)
        await tester.ensureVisible(expandPill);
        await tester.pumpAndSettle();
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
        final expandPill2 = find.byKey(const Key('expand_raw_notes_cluster_2'));
        await tester.scrollUntilVisible(expandPill2, 100,
            scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(expandPill2);
        await tester.pumpAndSettle();
        await tester.tap(expandPill2);
        await tester.pumpAndSettle();

        expect(find.text('From 1 thought'), findsOneWidget);
        expect(find.text('From 1 thoughts'), findsNothing);
        // [Move Out] must be hidden for 1-note cluster to prevent orphaned sessions
        expect(find.byKey(const Key('move_out_note_3')), findsNothing);
      },
    );

    testWidgets(
      'renders a card without error for every folder the engine can assign and for a folder not in the list',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final names = [...defaultFolders.map((f) => f.name), 'Ideas'];
        final clusters = [
          for (var i = 0; i < names.length; i++)
            SynthesisCluster(
              clusterId: 'cluster_$i',
              sequenceNumber: '#S-0${i + 1}',
              folder: names[i],
              synthesizedContent: 'Content $i',
              sessionStart: DateTime.now(),
              sessionEnd: DateTime.now(),
              sessionDuration: const Duration(minutes: 10),
              originNotes: const [],
              isUnread: true,
            ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore(openEditPrefs)),
              synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
            ],
            child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        for (var i = 0; i < names.length; i++) {
          // User decision 2026-11-28 (point 9): the folder menu is a chip that opens a chooser sheet;
          // it still shows the note's folder.
          final chip = find.byKey(Key('cluster_folder_dropdown_cluster_$i'));
          expect(find.descendant(of: chip, matching: find.text(names[i])), findsOneWidget);
        }

        // Every assignable folder can be chosen in the folder panel, and so can a folder that is
        // not in the list but still holds a note.
        await tester.tap(find.byKey(const Key('synthesis_folder_button')));
        await tester.pumpAndSettle();
        for (final f in defaultFolders) {
          expect(find.byKey(Key('folder_panel_row_${f.name}')), findsOneWidget);
        }
        expect(find.byKey(const Key('folder_panel_row_Ideas')), findsOneWidget);
      },
    );

    testWidgets(
      'The folder panel correctly filters clusters by folder and triage status',
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
            clusterId: 'cluster_personal',
            sequenceNumber: '#S-02',
            folder: 'Personal',
            synthesizedContent: 'Personal cluster content',
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
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_work')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_personal')),
            findsOneWidget);

        // Filter by Triage: Unread (a chip at the top of the folder panel)
        await tester.tap(find.byKey(const Key('synthesis_folder_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('triage_chip_unread')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('synthesis_filter_badge')), findsOneWidget);

        // Only #S-01 is unread
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_work')),
            findsOneWidget);
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_personal')),
            findsNothing);

        // Filter by folder: Personal has no unread note
        await tester.tap(find.byKey(const Key('folder_panel_row_Personal')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_work')), findsNothing);
        expect(find.byKey(const Key('synthesis_cluster_card_cluster_personal')), findsNothing);
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

    testWidgets(
      'card renders the note Markdown without asterisks and keeps the stored text intact',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const stored = '**Flat and Contract Updates**\n\n'
            "**Daniel's contract**\n"
            '- I signed the contract with Daniel on Monday.\n';
        final cluster = SynthesisCluster(
          clusterId: 'cluster_md',
          sequenceNumber: '#S-09',
          folder: 'Work',
          synthesizedContent: stored,
          sessionStart: DateTime.now().subtract(const Duration(minutes: 30)),
          sessionEnd: DateTime.now(),
          sessionDuration: const Duration(minutes: 30),
          originNotes: const [],
          isUnread: false,
          isActionExtracted: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notesRepositoryProvider.overrideWithValue(NotesRepository()),
              notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore(openReadPrefs)),
              synthesisRepositoryProvider.overrideWith(
                () => SynthesisRepository([cluster]),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SynthesisScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The title is on the row only: the opened note does not repeat it (TASK-093, user review 2026-11-27).
        expect(find.text('Flat and Contract Updates'), findsOneWidget);
        expect(find.text("Daniel's contract"), findsOneWidget);
        expect(find.text('I signed the contract with Daniel on Monday.'),
            findsOneWidget);
        expect(find.textContaining('*'), findsNothing);
        expect(tester.takeException(), isNull);
        expect(cluster.synthesizedContent, stored);
      },
    );

    testWidgets('the folder panel and the note folder menu list the user\'s folders', (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cluster = SynthesisCluster(
        clusterId: 'c1',
        sequenceNumber: '#S-01',
        folder: 'Garden',
        synthesizedContent: 'Water the tomatoes.',
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
        sessionDuration: const Duration(minutes: 5),
        originNotes: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(NotesRepository()),
            notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore()),
            folderStoreProvider.overrideWithValue(_StoredFolders(const [
              FolderDefinition(name: 'Garden', description: 'plants.'),
              FolderDefinition(name: 'Work', description: 'the job.'),
            ])),
            synthesisRepositoryProvider.overrideWith(() => SynthesisRepository([cluster])),
          ],
          child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('synthesis_folder_button')));
      await tester.pumpAndSettle();
      expect(find.text('Garden'), findsWidgets);
      expect(find.text('Personal'), findsNothing, reason: 'a default folder the user no longer has');
      await tester.tap(find.byKey(const Key('folder_panel_row_Garden')));
      await tester.pumpAndSettle();
      expect(find.text('Water the tomatoes.'), findsOneWidget);

      // The folder menu is a control of Edit mode, on an opened note.
      await tester.tap(find.byKey(const Key('synthesis_mode_edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('note_row_c1')));
      await tester.pumpAndSettle();

      // User decision 2026-11-28 (point 9): the chooser is a sheet; it offers the same folders.
      await tester.tap(find.byKey(const Key('cluster_folder_dropdown_c1')));
      await tester.pumpAndSettle();
      final offered = [
        for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('folder_option_')).evaluate())
          (e.widget.key as ValueKey<String>).value.substring('folder_option_'.length),
      ];
      expect(offered, ['Garden', 'Work', 'Uncategorized']);
      expect(tester.takeException(), isNull);
    });
  });
}
