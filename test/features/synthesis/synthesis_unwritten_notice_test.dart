import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/unwritten_thoughts.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/notes_view_prefs.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_notices.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

import 'notes_view_test_support.dart';

// User decision 2026-11-28 (TASK-108 C, product rule FR11.28): when a run could not write a
// thought, the Synthesis banner says so and says the thought is safe.
Note _thought(String text, {int attempts = 0, ThoughtState state = ThoughtState.processed}) =>
    Note(correctedText: text, rawText: text, state: state)..synthesisAttempts = attempts;

const _singular = '1 thought could not be written into a note last time: the reply was incomplete, '
    'so nothing was saved. It is safe in Capture; Synthesize Now tries again.';
const _plural = '2 thoughts could not be written into a note last time: the reply was incomplete, '
    'so nothing was saved. They are safe in Capture; Synthesize Now tries again.';

void main() {
  Future<NotesRepository> pump(WidgetTester tester, List<Note> notes) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = NotesRepository();
    for (final n in notes) {
      await repo.saveNote(n);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(repo),
          notesViewPrefsStoreProvider.overrideWithValue(InMemoryNotesViewPrefsStore()),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: SynthesisScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('the second line of the Synthesis banner', () {
    testWidgets('is not there while no waiting thought has failed a run', (tester) async {
      await pump(tester, [_thought('fresh one'), _thought('fresh two')]);

      expect(find.byKey(const Key('pending_synthesis_batch_banner')), findsOneWidget);
      expect(find.text('2 thoughts ready for Synthesis'), findsOneWidget);
      expect(find.byKey(const Key('synthesis_unwritten_notice')), findsNothing);
    });

    testWidgets('says why for one thought that failed before, in the warning colour', (tester) async {
      await pump(tester, [_thought('fresh'), _thought('failed before', attempts: 1)]);

      expect(find.text('2 thoughts ready for Synthesis'), findsOneWidget);
      expect(find.text(_singular), findsOneWidget);
      final line = tester.widget<Text>(find.byKey(const Key('synthesis_unwritten_notice')));
      expect(line.style!.color, AppColors.accentWarning);
      expect(
        find.descendant(of: find.byKey(const Key('pending_synthesis_batch_banner')), matching: find.byKey(const Key('synthesis_unwritten_notice'))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the plural for several, and counts only thoughts still waiting', (tester) async {
      await pump(tester, [
        _thought('a', attempts: 2),
        _thought('b', attempts: 1),
        _thought('written already', attempts: 3, state: ThoughtState.synthesized),
        _thought('fresh'),
      ]);

      expect(find.text(_plural), findsOneWidget);
    });

    testWidgets('appears when a waiting thought fails a run while the screen is mounted', (tester) async {
      final repo = await pump(tester, [_thought('waiting')]);
      expect(find.byKey(const Key('synthesis_unwritten_notice')), findsNothing);

      await tester.runAsync(() async {
        final note = (await repo.getAllNotes()).single;
        note.synthesisAttempts = 1;
        await repo.saveNote(note);
      });
      // The in-memory repository has no change signal of its own; the app's one does.
      ProviderScope.containerOf(tester.element(find.byType(SynthesisScreen))).read(notesRevisionProvider.notifier).bump();
      await tester.pumpAndSettle();

      expect(find.text(_singular), findsOneWidget);
    });

    test('the count provider counts waiting thoughts with at least one counted attempt', () async {
      final repo = NotesRepository();
      await repo.saveNote(_thought('a', attempts: 1));
      await repo.saveNote(_thought('b'));
      await repo.saveNote(_thought('c', attempts: 4, state: ThoughtState.failed));
      final container = ProviderContainer(overrides: [notesRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      expect(await container.read(unwrittenThoughtsCountProvider.future), 1);
    });

    testWidgets('is left out while a run is on: the thoughts are being tried again', (tester) async {
      Widget banner({required bool busy}) => MaterialApp(
            home: Scaffold(
              body: PendingThoughtsBanner(pendingThoughts: 2, unwrittenThoughts: 2, busy: busy, onSynthesizeNow: () {}),
            ),
          );
      await tester.pumpWidget(banner(busy: false));
      expect(find.byKey(const Key('synthesis_unwritten_notice')), findsOneWidget);

      await tester.pumpWidget(banner(busy: true));
      expect(find.byKey(const Key('synthesis_unwritten_notice')), findsNothing);
      expect(find.text('2 thoughts ready for Synthesis'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fits a 360 dp phone with the plural text (no overflow)', (tester) async {
      await pump(tester, [_thought('a', attempts: 1), _thought('b', attempts: 1)]);

      expect(tester.takeException(), isNull);
      final banner = tester.getRect(find.byKey(const Key('pending_synthesis_batch_banner')));
      expect(banner.left, greaterThanOrEqualTo(0));
      expect(banner.right, lessThanOrEqualTo(360));
    });
  });
}
