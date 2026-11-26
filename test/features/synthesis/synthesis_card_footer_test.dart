import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/core/formatting/thought_timestamp.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_texts.dart';

import 'notes_view_test_support.dart';

SynthesisCluster _cluster({
  required String id,
  required DateTime start,
  required Duration duration,
  int origins = 3,
}) {
  return SynthesisCluster(
    clusterId: 'cluster_$id',
    sequenceNumber: id,
    folder: 'Work',
    synthesizedContent: 'A synthesized note.',
    sessionStart: start,
    sessionEnd: start.add(duration),
    sessionDuration: duration,
    originNotes: [
      for (var i = 0; i < origins; i++)
        SynthesisOriginNote(
          id: 100 + i,
          formattedSequence: '#0${i + 1}',
          cleanedText: 'Origin $i',
          timestamp: start,
        ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, List<SynthesisCluster> clusters, {NotesRepository? notes}) async {
  tester.view.physicalSize = const Size(360, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (notes != null) notesRepositoryProvider.overrideWithValue(notes),
        // The footer is part of an opened note.
        notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore(openReadPrefs)),
        synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
      ],
      child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Synthesis note footer', () {
    testWidgets('shows the date day first, like the Capture cards', (tester) async {
      // 26 November, 14:37: month/day order would read 11/26.
      await _pump(tester, [
        _cluster(id: '#S-01', start: DateTime(2026, 11, 26, 14, 37), duration: const Duration(minutes: 30)),
      ]);

      expect(find.textContaining('26/11  02:37 PM'), findsOneWidget);
      expect(find.textContaining('11/26'), findsNothing);
      expect(formatThoughtTimestamp(DateTime(2026, 11, 26, 14, 37)), '26/11  02:37 PM');
      expect(formatThoughtTimestamp(DateTime(2026, 1, 5, 0, 5)), '05/01  12:05 AM');
    });

    testWidgets('hides the session length when it is under one minute', (tester) async {
      await _pump(tester, [
        _cluster(id: '#S-01', start: DateTime(2026, 11, 26, 14, 37), duration: const Duration(seconds: 40)),
        _cluster(id: '#S-02', start: DateTime(2026, 11, 25, 9, 5), duration: const Duration(minutes: 12)),
      ]);

      expect(find.text('26/11  02:37 PM'), findsOneWidget);
      expect(find.textContaining('0m session'), findsNothing);
      expect(find.text('25/11  09:05 AM • ⏱️ 12m session'), findsOneWidget);
    });

    testWidgets('the link says thought for one and thoughts for several', (tester) async {
      await _pump(tester, [
        _cluster(id: '#S-01', start: DateTime(2026, 11, 26, 14, 37), duration: const Duration(minutes: 5), origins: 1),
        _cluster(id: '#S-02', start: DateTime(2026, 11, 25, 9, 5), duration: const Duration(minutes: 5), origins: 3),
      ]);

      expect(find.text('From 1 thought'), findsOneWidget);
      expect(find.text('From 3 thoughts'), findsOneWidget);
      expect(find.text('From 1 thoughts'), findsNothing);
    });
  });

  group('Pending synthesis banner wording', () {
    test('describeThoughtsReadyForSynthesis uses singular and plural', () {
      expect(describeThoughtsReadyForSynthesis(1), '1 thought ready for Synthesis');
      expect(describeThoughtsReadyForSynthesis(3), '3 thoughts ready for Synthesis');
    });

    testWidgets('three waiting thoughts read as plural, with one icon and no emoji', (tester) async {
      final notes = NotesRepository();
      for (var i = 0; i < 3; i++) {
        await notes.saveNote(Note(rawText: 't$i', correctedText: 't$i', state: ThoughtState.processed));
      }
      await _pump(tester, const [], notes: notes);

      expect(find.text('3 thoughts ready for Synthesis'), findsOneWidget);
      expect(find.textContaining('🧩'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('pending_synthesis_batch_banner')),
          matching: find.byIcon(Icons.extension_outlined),
        ),
        findsOneWidget,
      );
    });
  });
}
