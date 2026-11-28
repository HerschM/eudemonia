import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/note_style.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

import '../settings/fake_permission_gateway.dart';
import 'capture_test_doubles.dart';
import 'capture_view_test_helpers.dart';

class _NoQueueItems extends QueueItemsNotifier {
  @override
  List<Never> build() => const [];
}

class _RunnerThatNeverFinishes implements SynthesisRunner {
  int runs = 0;
  final Completer<SynthesisRunResult> answer = Completer();

  @override
  Future<SynthesisRunResult> run({required bool manual}) {
    runs++;
    return answer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  late ProviderContainer container;
  late _RunnerThatNeverFinishes runner;
  String? clipboard;

  setUp(() {
    clipboard = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async => null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> saveNotes(WidgetTester tester, List<Note> notes) async {
    final repo = container.read(notesRepositoryProvider);
    await tester.runAsync(() async {
      for (final n in notes) {
        await repo.saveNote(n);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> pumpCapture(
    WidgetTester tester,
    List<Note> notes, {
    // Sessions built from the stored thoughts (with the ids the database gave them).
    List<SynthesisCluster> Function(List<Note> stored)? sessions,
    // Staying on a thought marks it read after 3 seconds; off, only a tap reads it.
    bool dwellReads = true,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    runner = _RunnerThatNeverFinishes();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWith(
            (ref) => NotesRepository(onChanged: () => ref.read(notesRevisionProvider.notifier).bump()),
          ),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(FakeNativeCaptureChannel()),
          captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          queueItemsProvider.overrideWith(_NoQueueItems.new),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
          synthesisRunnerProvider.overrideWithValue(runner),
          if (!dwellReads) selectedShellTabProvider.overrideWith(() => _FixedTab(ShellTab.synthesis)),
        ],
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(CaptureScreen)));
    await saveNotes(tester, notes);
    if (sessions != null) {
      final stored = (await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!;
      container.read(synthesisRepositoryProvider.notifier).state = sessions(stored);
      await tester.pumpAndSettle();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  // Decision A (2026-11-28): the triage dropdown became the Show group of the view panel; the
  // same labels pick the same filters ('All Triage' is now the row `All thoughts`).
  Future<void> pickTriage(WidgetTester tester, String label) =>
      pickCaptureView(tester, show: const {'Unread': 'unread', 'Read': 'read', 'All Triage': 'all'}[label]);

  Finder dotIn(String text) => find.descendant(
        of: find.ancestor(of: find.text(text), matching: find.byType(ThoughtCard)),
        matching: find.byKey(const Key('unread_dot')),
      );

  Finder deleteIn(String text) => find.descendant(
        of: find.ancestor(of: find.text(text), matching: find.byType(ThoughtCard)),
        matching: find.byKey(const Key('delete_note_button')),
      );

  SynthesisCluster sessionOf(String id, String label, List<Note> notes,
          {String content = '# Garden plans\n\n- plant beans', String style = defaultNoteStyleId}) =>
      SynthesisCluster(
        clusterId: id,
        sequenceNumber: label,
        folder: 'Work',
        synthesizedContent: content,
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
        sessionDuration: Duration.zero,
        originNotes: [for (final n in notes) SynthesisOriginNote.fromNote(n)],
        appliedStyleId: style,
      );

  Future<void> readByTap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  }

  group('A thought read while the Unread or Read filter shows it stays listed', () {
    testWidgets('reading an unread thought under Unread keeps it, with its dot dissolved', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'First unread.'), Note(correctedText: 'Second unread.')], dwellReads: false);
      await pickTriage(tester, 'Unread');
      expect(find.text('First unread.'), findsOneWidget);
      expect(find.text('Second unread.'), findsOneWidget);

      await readByTap(tester, 'First unread.');

      expect(find.text('First unread.'), findsOneWidget, reason: 'was being read');
      expect(dotIn('First unread.'), findsNothing, reason: 'it is read now');
      expect(find.text('Second unread.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('dwelling for 3 seconds reads it and it still stays', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Dwelled on.')]);
      await pickTriage(tester, 'Unread');

      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();

      expect(find.text('Dwelled on.'), findsOneWidget);
      expect(dotIn('Dwelled on.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('picking Unread again, or another filter, drops the thoughts that are no longer unread',
        (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'First unread.'), Note(correctedText: 'Second unread.')], dwellReads: false);
      await pickTriage(tester, 'Unread');
      await readByTap(tester, 'First unread.');
      expect(find.text('First unread.'), findsOneWidget);

      await pickTriage(tester, 'Unread');
      expect(find.text('First unread.'), findsNothing, reason: 'same chip again starts a new listing');
      expect(find.text('Second unread.'), findsOneWidget);

      await pickTriage(tester, 'Read');
      expect(find.text('First unread.'), findsOneWidget, reason: 'it is read, so it belongs under Read');
      expect(find.text('Second unread.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a thought that is listed under Read stays listed; the kept set is dropped by All', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Seen one.', isRead: true), Note(correctedText: 'Unseen one.')]);
      await pickTriage(tester, 'Read');
      expect(find.text('Seen one.'), findsOneWidget);
      expect(find.text('Unseen one.'), findsNothing);

      // It becomes unread from elsewhere (here: through the repository), while the user looks at it.
      final repo = container.read(notesRepositoryProvider);
      final stored = (await tester.runAsync(repo.getAllNotes))!.firstWhere((n) => n.correctedText == 'Seen one.');
      await tester.runAsync(() async {
        stored.isRead = false;
        await repo.saveNote(stored);
      });
      await tester.pumpAndSettle();
      expect(find.text('Seen one.'), findsOneWidget, reason: 'stays while Read is showing');

      await pickTriage(tester, 'All Triage');
      await pickTriage(tester, 'Read');
      expect(find.text('Seen one.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a new thought that matches the filter still appears', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Old unread.')], dwellReads: false);
      await pickTriage(tester, 'Unread');
      await readByTap(tester, 'Old unread.');

      await saveNotes(tester, [Note(correctedText: 'Brand new unread.')]);

      expect(find.text('Brand new unread.'), findsOneWidget);
      expect(find.text('Old unread.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a thought that was never listed does not join the kept set when it is read elsewhere',
        (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Seen already.', isRead: true), Note(correctedText: 'Unseen.')]);
      await pickTriage(tester, 'Unread');
      expect(find.text('Seen already.'), findsNothing);
      await unmount(tester);
    });
  });

  group('Delete asks first and says what else changes', () {
    testWidgets('a loose thought: the question names its number and there is no consequence line', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Loose thought.', dailySequenceNumber: 7, isRead: true)]);

      await tester.tap(deleteIn('Loose thought.'));
      await tester.pumpAndSettle();

      expect(find.text('Delete thought #07?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_consequence')), findsNothing);
      await unmount(tester);
    });

    testWidgets('Cancel changes nothing; Delete removes the thought', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Loose thought.', dailySequenceNumber: 7, isRead: true)]);

      await tester.tap(deleteIn('Loose thought.'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Loose thought.'), findsOneWidget);
      expect((await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!, hasLength(1));

      await tester.tap(deleteIn('Loose thought.'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();
      expect(find.text('Loose thought.'), findsNothing);
      expect((await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!, isEmpty);
      await unmount(tester);
    });

    testWidgets('the only thought of a note: the note is named as deleted too, and goes on Delete', (tester) async {
      final only = Note(correctedText: 'Only thought.', dailySequenceNumber: 2, state: ThoughtState.synthesized, isRead: true);
      await pumpCapture(tester, [only], sessions: (stored) => [sessionOf('c1', '#S-03', stored)]);

      await tester.tap(deleteIn('Only thought.'));
      await tester.pumpAndSettle();
      expect(find.text('Delete thought #02?'), findsOneWidget);
      expect(find.text('Note #S-03 "Garden plans" will be deleted too.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_delete_cancel')));
      await tester.pumpAndSettle();
      expect(container.read(synthesisRepositoryProvider), hasLength(1), reason: 'cancel changes nothing');

      await tester.tap(deleteIn('Only thought.'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();
      expect(container.read(synthesisRepositoryProvider), isEmpty);
      await unmount(tester);
    });

    testWidgets('a note with other thoughts is named as rewritten without this one', (tester) async {
      final a = Note(correctedText: 'Thought A.', dailySequenceNumber: 1, state: ThoughtState.synthesized, isRead: true);
      final b = Note(correctedText: 'Thought B.', dailySequenceNumber: 2, state: ThoughtState.synthesized, isRead: true);
      await pumpCapture(tester, [a, b], sessions: (stored) => [sessionOf('c1', '#S-03', stored)]);

      await tester.tap(deleteIn('Thought A.'));
      await tester.pumpAndSettle();
      expect(find.text('Note #S-03 "Garden plans" will be rewritten without this thought.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();
      expect(find.text('Thought A.'), findsNothing);
      expect(container.read(synthesisRepositoryProvider).single.originNotes, hasLength(1));
      expect(container.read(synthesisRepositoryProvider).single.isReprocessing, isTrue);
      await unmount(tester);
    });

    testWidgets('a hand-edited note is named as staying as it is, which is what happens to it', (tester) async {
      final a = Note(correctedText: 'Thought A.', dailySequenceNumber: 1, state: ThoughtState.synthesized, isRead: true);
      final b = Note(correctedText: 'Thought B.', dailySequenceNumber: 2, state: ThoughtState.synthesized, isRead: true);
      await pumpCapture(tester, [a, b], sessions: (stored) => [sessionOf('c1', '#S-03', stored, style: manualStyleId)]);

      await tester.tap(deleteIn('Thought A.'));
      await tester.pumpAndSettle();
      expect(
        find.text('Note #S-03 "Garden plans" was edited by hand, so its text stays as it is; '
            'this thought is only removed from its source thoughts.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();
      final session = container.read(synthesisRepositoryProvider).single;
      expect(session.synthesizedContent, '# Garden plans\n\n- plant beans', reason: 'the text is untouched');
      expect(session.isReprocessing, isFalse, reason: 'no rewrite is asked for');
      expect(runner.runs, 0);
      await unmount(tester);
    });
  });

  group('Copy', () {
    testWidgets('the Copy button puts the thought on the clipboard and says Copied', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Copy this thought.', isRead: true)]);

      await tester.tap(find.byKey(const Key('thought_copy_button')));
      await tester.pump();

      expect(clipboard, 'Copy this thought.');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('a long press on the card copies the thought', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Hold this thought.', isRead: true)]);

      await tester.longPress(find.text('Hold this thought.'));
      await tester.pump();

      expect(clipboard, 'Hold this thought.');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });
  });

  group('Synthesized filter icon', () {
    testWidgets('uses the hub icon, not the star', (tester) async {
      await pumpCapture(tester, []);
      // Decision A (2026-11-28): the status dropdown became the Status group of the view panel.
      await tester.tap(find.byKey(const Key('capture_view_button')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hub_outlined), findsWidgets);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      await unmount(tester);
    });
  });
}

class _FixedTab extends SelectedShellTabNotifier {
  final ShellTab initial;
  _FixedTab(this.initial);

  @override
  ShellTab? build() => initial;
}
