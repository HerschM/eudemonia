import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_item.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/home/application/pipeline_status.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/presentation/thought_card.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';

import '../settings/fake_permission_gateway.dart';
import 'capture_test_doubles.dart';
import 'capture_view_test_helpers.dart';

class _NoQueueItems extends QueueItemsNotifier {
  @override
  List<AudioQueueItem> build() => const [];
}

class _IdleRunner implements SynthesisRunner {
  @override
  Future<SynthesisRunResult> run({required bool manual}) async => SynthesisRunResult.nothingToDo;

  @override
  bool get isRunning => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  late ProviderContainer container;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => call.method == 'isForegroundServiceRunning');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  ProviderScope scope(Widget child) => ProviderScope(
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
          synthesisRunnerProvider.overrideWithValue(_IdleRunner()),
          activeSynthesisProfileProvider.overrideWithValue(ModelCatalogue.qwen3_4b.profile!),
        ],
        child: child,
      );

  /// Stores [notes] and returns them as stored (with their ids), oldest first as given.
  Future<List<Note>> store(WidgetTester tester, List<Note> notes) async {
    final repo = container.read(notesRepositoryProvider);
    await tester.runAsync(() async {
      for (final n in notes) {
        await repo.saveNote(n);
      }
    });
    return (await tester.runAsync(repo.getAllNotes))!;
  }

  Future<void> pumpCapture(WidgetTester tester, {List<Note> notes = const [], int? requestBefore}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The screen is built after the request exists, as when the shell shows the tab for it.
    container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWith(
        (ref) => NotesRepository(onChanged: () => ref.read(notesRevisionProvider.notifier).bump()),
      ),
      runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
      nativeCaptureChannelProvider.overrideWithValue(FakeNativeCaptureChannel()),
      captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
      modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
      queueItemsProvider.overrideWith(_NoQueueItems.new),
      synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
      synthesisRunnerProvider.overrideWithValue(_IdleRunner()),
    ]);
    addTearDown(container.dispose);
    final stored = await store(tester, notes);
    if (requestBefore != null) {
      container.read(captureFocusRequestProvider.notifier).request(stored[requestBefore].id);
    }
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: CaptureScreen())));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Finder cardOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(ThoughtCard));

  bool glows(WidgetTester tester, String text) => tester.widget<ThoughtCard>(cardOf(text)).highlighted;

  List<Note> manyThoughts(int n) => [
        for (var i = 0; i < n; i++)
          Note(
            correctedText: 'Thought number $i.',
            // The first is the newest; the last of the list is the oldest, far down the feed.
            createdAt: DateTime.now().subtract(Duration(minutes: i)),
            isRead: true,
          ),
      ];

  group('a thought brought into view (decision D, 2026-11-28)', () {
    testWidgets('a request for a thought far down scrolls to it, glows, then calms down; it is consumed', (tester) async {
      await pumpCapture(tester, notes: manyThoughts(25));
      // The oldest is not built at all (lazy list), so the request must be able to reach it.
      expect(find.text('Thought number 24.'), findsNothing);
      final target = (await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!
          .firstWhere((n) => n.correctedText == 'Thought number 24.');

      container.read(captureFocusRequestProvider.notifier).request(target.id);
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(container.read(captureFocusRequestProvider), isNull, reason: 'consumed');
      expect(find.text('Thought number 24.'), findsOneWidget);
      expect(tester.getTopLeft(cardOf('Thought number 24.')).dy, inInclusiveRange(0, 700), reason: 'in view');
      expect(glows(tester, 'Thought number 24.'), isTrue);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));
      expect(glows(tester, 'Thought number 24.'), isFalse);
      await unmount(tester);
    });

    testWidgets('a filter that hides the thought is reset; a filter that does not hide it stays', (tester) async {
      await pumpCapture(tester, notes: [
        Note(correctedText: 'Unread one.'),
        Note(correctedText: 'Seen and done.', isRead: true, state: ThoughtState.synthesized),
      ]);
      await pickCaptureView(tester, show: 'unread');
      expect(find.text('Seen and done.'), findsNothing);
      final target = (await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!
          .firstWhere((n) => n.correctedText == 'Seen and done.');

      container.read(captureFocusRequestProvider.notifier).request(target.id);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tester.widget<Text>(find.byKey(const Key('capture_view_title'))).data, 'All thoughts');
      expect(find.text('Seen and done.'), findsOneWidget);
      expect(glows(tester, 'Seen and done.'), isTrue);

      // A view that already lists it is left as the user set it.
      await pickCaptureView(tester, status: 'synthesized');
      container.read(captureFocusRequestProvider.notifier).request(target.id);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.widget<Text>(find.byKey(const Key('capture_view_title'))).data, 'Synthesized');
      expect(find.text('Seen and done.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('both filters hiding it are both reset, and the open panel closes', (tester) async {
      await pumpCapture(tester, notes: [
        Note(correctedText: 'Unread one.'),
        Note(correctedText: 'Seen and done.', isRead: true, state: ThoughtState.synthesized),
      ]);
      await pickCaptureView(tester, show: 'unread', status: 'processed');
      await tester.tap(find.byKey(const Key('capture_view_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('capture_view_panel')), findsOneWidget);
      final target = (await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!
          .firstWhere((n) => n.correctedText == 'Seen and done.');

      container.read(captureFocusRequestProvider.notifier).request(target.id);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tester.widget<Text>(find.byKey(const Key('capture_view_title'))).data, 'All thoughts');
      expect(find.byKey(const Key('capture_view_panel')), findsNothing);
      expect(find.text('Seen and done.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('a thought that no longer exists is reported, and the request is consumed', (tester) async {
      await pumpCapture(tester, notes: [Note(correctedText: 'Still here.')]);

      container.read(captureFocusRequestProvider.notifier).request(99999);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('That thought no longer exists.'), findsOneWidget);
      expect(container.read(captureFocusRequestProvider), isNull);
      expect(find.text('Still here.'), findsOneWidget, reason: 'the feed is left as it was');
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });

    testWidgets('a request made before the screen existed is honoured when it appears', (tester) async {
      await pumpCapture(tester, notes: manyThoughts(25), requestBefore: 0);
      // requestBefore points at the first stored note: the newest.
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(captureFocusRequestProvider), isNull);
      expect(glows(tester, 'Thought number 0.'), isTrue);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });
  });

  group('the shell shows the Capture tab for a request (decision D, 2026-11-28)', () {
    testWidgets('a pending request moves from Synthesis to Capture, where the thought glows', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(scope(const MaterialApp(home: MainNavigationShell(initialIndex: 1))));
      container = ProviderScope.containerOf(tester.element(find.byType(MainNavigationShell)));
      final stored = await store(tester, [Note(correctedText: 'Raw thought.', isRead: true)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      TabController tabs() => tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(tabs().index, 1);

      container.read(captureFocusRequestProvider.notifier).request(stored.single.id);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tabs().index, 0, reason: 'the Capture tab is shown');
      expect(container.read(captureFocusRequestProvider), isNull);
      expect(glows(tester, 'Raw thought.'), isTrue);
      await tester.pump(const Duration(seconds: 3));
      await unmount(tester);
    });
  });

  group('written notes on the Capture screen (decision C, 2026-11-28)', () {
    Note written(String text, {int minutesAgo = 0}) => Note(
          correctedText: text,
          rawText: text,
          isWritten: true,
          isRead: true,
          dailySequenceNumber: 7,
          createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        );

    testWidgets('a written note shows the pen where a voice thought shows play; the voice one keeps play', (tester) async {
      await pumpCapture(tester, notes: [
        written('Typed thought.'),
        Note(correctedText: 'Spoken thought.', originalAudioPath: '/a.wav', isRead: true, createdAt: DateTime.now().subtract(const Duration(minutes: 1))),
      ]);

      expect(find.descendant(of: cardOf('Typed thought.'), matching: find.byKey(const Key('written_note_marker'))), findsOneWidget);
      expect(find.descendant(of: cardOf('Typed thought.'), matching: find.byKey(const Key('play_audio_button'))), findsNothing);
      expect(find.descendant(of: cardOf('Spoken thought.'), matching: find.byKey(const Key('play_audio_button'))), findsOneWidget);
      expect(find.descendant(of: cardOf('Spoken thought.'), matching: find.byKey(const Key('written_note_marker'))), findsNothing);
      await unmount(tester);
    });

    testWidgets('tap the text of a written note, edit and save: stored through the same path', (tester) async {
      await pumpCapture(tester, notes: [written('Typed thought.')]);

      await tester.tap(find.text('Typed thought.'));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('inline_edit_textfield')), 'Typed, then changed.');
      await tester.tap(find.byKey(const Key('save_edit_button')));
      await tester.pumpAndSettle();

      final stored = (await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes))!.single;
      expect(stored.correctedText, 'Typed, then changed.');
      expect(stored.isWritten, isTrue);
      await unmount(tester);
    });

    testWidgets('deleting a written note works without any recording to remove', (tester) async {
      await pumpCapture(tester, notes: [written('Typed thought.')]);

      await tester.tap(find.byKey(const Key('delete_note_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('Typed thought.'), findsNothing);
      expect(await tester.runAsync(container.read(notesRepositoryProvider).getAllNotes), isEmpty);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('a written note is a thought ready for Synthesis like a transcribed one', (tester) async {
      await pumpCapture(tester, notes: [written('Typed thought.')]);

      // What the `1 thought ready for Synthesis` line and the automatic trigger read.
      expect(await tester.runAsync(() => container.read(rawNotesReadyToClusterCountProvider.future)), 1);
      container.read(pipelineStatusProvider);
      await tester.pump();
      expect(container.read(pipelineStatusProvider).readyThoughts, 1);
      await unmount(tester);
    });
  });
}
