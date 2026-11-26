import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/home/presentation/pipeline_hud_modal.dart';
import 'package:eudemonia/features/models/application/model_library_controller.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/application/synthesis_runner.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';

class _NoQueue extends PendingQueueCountNotifier {
  @override
  int build() => 0;
}

class _RunnerThatNeverStarts implements SynthesisRunner {
  final Completer<SynthesisRunResult> answer = Completer();
  int runs = 0;

  @override
  Future<SynthesisRunResult> run({required bool manual}) {
    runs++;
    return answer.future;
  }

  @override
  bool get isRunning => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

SynthesisCluster _session(String id, String label, DateTime start, {List<SynthesisOriginNote> origins = const [], bool unread = false}) =>
    SynthesisCluster(
      clusterId: id,
      sequenceNumber: label,
      folder: 'Work',
      synthesizedContent: 'Narrative of $id',
      sessionStart: start,
      sessionEnd: start,
      sessionDuration: Duration.zero,
      originNotes: origins,
      isUnread: unread,
    );

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');
  late ProviderContainer container;
  late _RunnerThatNeverStarts runner;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => call.method == 'isForegroundServiceRunning');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    List<Note> notes = const [],
    List<SynthesisCluster> clusters = const [],
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Made inside the test: its futures must complete in the test's fake-async zone.
    runner = _RunnerThatNeverStarts();
    final repo = NotesRepository();
    for (final n in notes) {
      await repo.saveNote(n);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(repo),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(clusters)),
          pendingQueueCountProvider.overrideWith(_NoQueue.new),
          activeSynthesisProfileProvider.overrideWithValue(ModelCatalogue.qwen3_4b.profile!),
          synthesisRunnerProvider.overrideWithValue(runner),
        ],
        child: const MaterialApp(home: MainNavigationShell()),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(MainNavigationShell)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  TabController tabs(WidgetTester tester) => tester.widget<TabBar>(find.byType(TabBar)).controller!;

  group('Swiping between the stages (UX 6.A)', () {
    testWidgets('swiping the body left and right moves between Capture and Synthesis; the bar follows',
        (tester) async {
      await pumpShell(tester);
      expect(tabs(tester).index, 0);
      expect(find.byKey(const Key('synthesis_mode_toggle')), findsNothing);

      final gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(-30, 0)); // gets past the touch slop
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      final mid = tabs(tester).animation!.value;
      expect(mid, inExclusiveRange(0.0, 1.0), reason: 'the pill is between the two positions mid-swipe');
      await gesture.moveBy(const Offset(-150, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tabs(tester).index, 1);
      expect(find.byKey(const Key('synthesis_mode_toggle')), findsOneWidget);
      expect(container.read(selectedShellTabProvider), ShellTab.synthesis);

      await tester.fling(find.byType(TabBarView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 0);
      expect(find.byKey(const Key('synthesis_mode_toggle')), findsNothing);
      expect(container.read(selectedShellTabProvider), ShellTab.capture);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('vertical scrolling still works inside a swiped page and each tab keeps its scroll position',
        (tester) async {
      // Seen thoughts that are already synthesized: nothing waits for synthesis, so no banner.
      await pumpShell(tester, notes: [
        for (var i = 0; i < 20; i++)
          Note(correctedText: 'Thought number $i', isRead: true, state: ThoughtState.synthesized),
      ]);
      final list = find.descendant(of: find.byType(CaptureScreen), matching: find.byType(Scrollable)).first;
      final before = tester.state<ScrollableState>(list).position.pixels;
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      final scrolled = tester.state<ScrollableState>(list).position.pixels;
      expect(scrolled, greaterThan(before));
      expect(tabs(tester).index, 0, reason: 'a vertical drag does not change the stage');

      await tester.tap(find.text('Synthesis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(list).position.pixels, scrolled);
      await unmount(tester);
    });

    testWidgets('tapping a tab shows no rectangular splash and the pill follows the controller', (tester) async {
      await pumpShell(tester);

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.splashFactory, NoSplash.splashFactory);
      expect(bar.overlayColor!.resolve({WidgetState.pressed}), Colors.transparent);
      expect(bar.overlayColor!.resolve({WidgetState.hovered}), Colors.transparent);

      await tester.tap(find.text('Synthesis'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tabs(tester).animation!.value, inExclusiveRange(0.0, 1.0), reason: 'the pill is sliding');
      await tester.pumpAndSettle();
      expect(tabs(tester).index, 1);
      await unmount(tester);
    });
  });

  group('Unread counts follow what was seen (FR9.10)', () {
    testWidgets('the Capture count includes unseen synthesized thoughts and leaves out seen ones', (tester) async {
      await pumpShell(tester, notes: [
        Note(correctedText: 'Fresh', state: ThoughtState.processed),
        Note(correctedText: 'Unseen clubbed', state: ThoughtState.synthesized),
        Note(correctedText: 'Seen clubbed', state: ThoughtState.synthesized, isRead: true),
      ]);

      expect(find.text('Capture (2)'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('A synthesis run is visible (FR11.16)', () {
    testWidgets('the pill, the banner and the HUD show Synthesizing… from the tap and until the run ends',
        (tester) async {
      await pumpShell(
        tester,
        notes: [Note(correctedText: 'Waiting thought')],
        clusters: [_session('s0', '#S-01', DateTime.now())],
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('in Pipeline'), findsOneWidget);

      // Start from the Pipeline HUD.
      await tester.tap(find.byKey(const Key('top_ai_pipeline_pill')));
      await tester.pumpAndSettle();
      expect(find.byType(PipelineHudModal), findsOneWidget);
      await tester.tap(find.byKey(const Key('hud_synthesize_now_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(runner.runs, 1);
      expect(find.text('Synthesizing…'), findsOneWidget, reason: 'the pill');
      expect(find.textContaining('in Pipeline'), findsNothing);

      // On the Synthesis screen the banner shows it too.
      await tester.tap(find.text('Synthesis'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('synthesize_now_banner_button')), findsOneWidget);
      expect(find.text('Synthesizing…'), findsNWidgets(2), reason: 'pill and banner');
      final banner = find.byKey(const Key('synthesize_now_banner_button'));
      expect(tester.widget<InkWell>(find.descendant(of: banner, matching: find.byType(InkWell))).onTap, isNull);

      // The HUD opened now shows it as well.
      await tester.tap(find.byKey(const Key('top_ai_pipeline_pill')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Synthesizing…'), findsNWidgets(3), reason: 'pill, banner and HUD');
      await tester.tap(find.byKey(const Key('close_pipeline_hud_button')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // The runner says it could not start: everything returns.
      runner.answer.complete(SynthesisRunResult.busy);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Synthesizing…'), findsNothing);
      expect(find.text('Synthesize Now'), findsOneWidget);
      expect(find.text('Capture is busy. Try again in a moment.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('The session number on a Capture card opens that note (FR9.9)', () {
    testWidgets('tapping the badge switches to Synthesis, scrolls to the note and highlights it', (tester) async {
      final now = DateTime.now();
      final clubbed = Note(correctedText: 'Clubbed thought', state: ThoughtState.synthesized, isRead: true)..id = 90;
      await pumpShell(
        tester,
        notes: [clubbed],
        clusters: [
          // The wanted session is the oldest, far below the newer ones.
          for (var i = 1; i <= 20; i++)
            _session('s$i', '#S-${i.toString().padLeft(2, '0')}', DateTime(now.year, now.month, now.day - 1, 8),
                origins: i == 1 ? [SynthesisOriginNote.fromNote(clubbed)] : const []),
        ],
      );
      expect(find.text('Clubbed thought'), findsOneWidget);

      await tester.tap(find.byKey(const Key('synthesized_badge')));
      // The tab slides over, the screen appears, takes the request, builds, scrolls: a few frames.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tabs(tester).index, 1);
      expect(find.byType(SynthesisScreen), findsOneWidget);
      final card = find.byKey(sessionCardKey('s1'));
      expect(card, findsOneWidget);
      expect(tester.getTopLeft(card).dy, inInclusiveRange(0, 700));
      expect(tester.widget<AnimatedContainer>(card).decoration, isA<BoxDecoration>());
      expect((tester.widget<AnimatedContainer>(card).decoration! as BoxDecoration).boxShadow, isNotEmpty);
      expect(container.read(synthesisFocusRequestProvider), isNull);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 500));
      expect((tester.widget<AnimatedContainer>(card).decoration! as BoxDecoration).boxShadow, isEmpty);
      await unmount(tester);
    });
  });
}
