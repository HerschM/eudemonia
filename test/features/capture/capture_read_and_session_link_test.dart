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
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';

import '../settings/fake_permission_gateway.dart';
import 'capture_test_doubles.dart';
import 'capture_view_test_helpers.dart';

class _NoQueueItems extends QueueItemsNotifier {
  @override
  List<Never> build() => const [];
}

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  late ProviderContainer container;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpCapture(
    WidgetTester tester,
    List<Note> notes, {
    List<SynthesisCluster> clusters = const [],
    ShellTab? shellTab,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // As in production: a change made through the repository refreshes the feed.
          notesRepositoryProvider.overrideWith(
            (ref) => NotesRepository(onChanged: () => ref.read(notesRevisionProvider.notifier).bump()),
          ),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(FakeNativeCaptureChannel()),
          captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          queueItemsProvider.overrideWith(_NoQueueItems.new),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
          if (shellTab != null) selectedShellTabProvider.overrideWith(() => _FixedTab(shellTab)),
        ],
        child: const MaterialApp(home: CaptureScreen()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(CaptureScreen)));
    final repo = container.read(notesRepositoryProvider);
    await tester.runAsync(() async {
      for (final n in notes) {
        await repo.saveNote(n);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  SynthesisCluster sessionOf(String id, String label, List<Note> notes) => SynthesisCluster(
        clusterId: id,
        sequenceNumber: label,
        folder: 'Work',
        synthesizedContent: 'Narrative',
        sessionStart: DateTime.now(),
        sessionEnd: DateTime.now(),
        sessionDuration: Duration.zero,
        originNotes: [for (final n in notes) SynthesisOriginNote.fromNote(n)],
      );

  Finder dotIn(String text) => find.descendant(
        of: find.ancestor(of: find.text(text), matching: find.byType(ThoughtCard)),
        matching: find.byKey(const Key('unread_dot')),
      );

  group('Unread means not yet seen, in every state (FR9.10)', () {
    testWidgets('a synthesized thought that was not seen shows the dot; a seen one does not', (tester) async {
      await pumpCapture(tester, [
        Note(correctedText: 'Unseen synthesized', state: ThoughtState.synthesized),
        Note(correctedText: 'Seen synthesized', state: ThoughtState.synthesized, isRead: true),
        Note(correctedText: 'Unseen processed'),
      ]);

      expect(dotIn('Unseen synthesized'), findsOneWidget);
      expect(dotIn('Seen synthesized'), findsNothing);
      expect(dotIn('Unseen processed'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the Unread and Read filters follow what was seen, not the state', (tester) async {
      await pumpCapture(tester, [
        Note(correctedText: 'Unseen synthesized', state: ThoughtState.synthesized),
        Note(correctedText: 'Seen synthesized', state: ThoughtState.synthesized, isRead: true),
        Note(correctedText: 'Seen processed', isRead: true),
      ]);

      // Decision A (2026-11-28): the two dropdowns became the view panel; same filter, same assertions.
      await pickCaptureView(tester, show: 'unread');
      expect(find.text('Unseen synthesized'), findsOneWidget);
      expect(find.text('Seen synthesized'), findsNothing);
      expect(find.text('Seen processed'), findsNothing);

      // Decision A (2026-11-28): the two dropdowns became the view panel; same filter, same assertions.
      await pickCaptureView(tester, show: 'read');
      expect(find.text('Unseen synthesized'), findsNothing);
      expect(find.text('Seen synthesized'), findsOneWidget);
      expect(find.text('Seen processed'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('tapping an unseen synthesized thought marks it read and the dot dissolves', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Unseen synthesized', state: ThoughtState.synthesized)]);

      await tester.tap(find.text('Unseen synthesized'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(dotIn('Unseen synthesized'), findsOneWidget, reason: 'dissolving');
      await tester.pump(const Duration(milliseconds: 800));

      expect(dotIn('Unseen synthesized'), findsNothing);
      final stored = await tester.runAsync(() => container.read(notesRepositoryProvider).getAllNotes());
      expect(stored!.single.isRead, isTrue);
      await unmount(tester);
    });

    testWidgets('staying on a thought for 3 seconds marks it read', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Unseen processed')]);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(dotIn('Unseen processed'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(dotIn('Unseen processed'), findsNothing);
      final stored = await tester.runAsync(() => container.read(notesRepositoryProvider).getAllNotes());
      expect(stored!.single.isRead, isTrue);
      await unmount(tester);
    });

    testWidgets('a thought is not read while another tab is in front', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Unseen processed')], shellTab: ShellTab.synthesis);

      await tester.pump(const Duration(seconds: 10));
      expect(dotIn('Unseen processed'), findsOneWidget);

      container.read(selectedShellTabProvider.notifier).select(ShellTab.capture);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3100));
      await tester.pumpAndSettle();
      expect(dotIn('Unseen processed'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a thought that was already read is not read again by dwelling', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Seen processed', isRead: true)]);

      await tester.pump(const Duration(seconds: 10));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await unmount(tester);
    });
  });

  group('The session number on a synthesized thought opens that note (FR9.9)', () {
    testWidgets('tapping the badge asks for the session by its id', (tester) async {
      final clubbed = Note(correctedText: 'Clubbed thought', state: ThoughtState.synthesized, isRead: true)..id = 41;
      await pumpCapture(tester, [clubbed], clusters: [sessionOf('session-7', '#S-02', [clubbed])]);

      expect(find.text('🧩 Synthesized in #S-02'), findsOneWidget);
      await tester.tap(find.byKey(const Key('synthesized_badge')));
      await tester.pump();

      expect(container.read(synthesisFocusRequestProvider), 'session-7');
      expect(find.text('That note no longer exists.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('a session that is gone shows "That note no longer exists."', (tester) async {
      await pumpCapture(tester, [Note(correctedText: 'Orphan', state: ThoughtState.synthesized, isRead: true)]);

      await tester.tap(find.byKey(const Key('synthesized_badge')));
      await tester.pump();

      expect(find.text('That note no longer exists.'), findsOneWidget);
      expect(container.read(synthesisFocusRequestProvider), isNull);
      await tester.pump(const Duration(seconds: 5));
      await unmount(tester);
    });

    testWidgets('older days get a plain date header, like Synthesis', (tester) async {
      final now = DateTime.now();
      final old = DateTime(now.year, now.month, now.day - 3, 9);
      await pumpCapture(tester, [Note(correctedText: 'Old thought', createdAt: old, isRead: true)]);

      final dd = old.day.toString().padLeft(2, '0');
      final mm = old.month.toString().padLeft(2, '0');
      expect(find.text('$dd/$mm'), findsOneWidget);
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
