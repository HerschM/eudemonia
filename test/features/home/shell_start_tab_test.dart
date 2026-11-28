import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/audio_queue_service.dart';
import 'package:eudemonia/features/home/application/shell_state.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';

class _NoQueue extends PendingQueueCountNotifier {
  @override
  int build() => 0;
}

/// Sessions that arrive only after a delay, like the ones read from the database at startup.
class _SlowRepository extends SynthesisRepository {
  final Completer<void> release;
  final List<SynthesisCluster> stored;
  _SlowRepository(this.release, this.stored);

  @override
  Future<void> get hydrated => release.future;

  @override
  List<SynthesisCluster> build() => const [];

  void finishLoading() {
    state = stored;
    release.complete();
  }
}

SynthesisCluster _session() => SynthesisCluster(
      clusterId: 's1',
      sequenceNumber: '#S-01',
      folder: 'Work',
      synthesizedContent: 'Narrative',
      sessionStart: DateTime.now(),
      sessionEnd: DateTime.now(),
      sessionDuration: Duration.zero,
      originNotes: const [],
    );

void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => call.method == 'isForegroundServiceRunning');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    required SynthesisRepository Function() repo,
    int? initialIndex,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(NotesRepository()),
          pendingQueueCountProvider.overrideWith(_NoQueue.new),
          synthesisRepositoryProvider.overrideWith(repo),
        ],
        child: MaterialApp(home: MainNavigationShell(initialIndex: initialIndex)),
      ),
    );
  }

  TabController tabs(WidgetTester tester) => tester.widget<TabBar>(find.byType(TabBar)).controller!;

  group('Which tab the app opens on', () {
    testWidgets('at least one synthesis note: the very first frame is Synthesis', (tester) async {
      await pump(tester, repo: () => SynthesisRepository([_session()]));

      expect(tabs(tester).index, 1);
      expect(find.byType(SynthesisScreen), findsOneWidget);
      expect(find.byType(CaptureScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('no synthesis note: Capture', (tester) async {
      await pump(tester, repo: () => SynthesisRepository(const []));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tabs(tester).index, 0);
      expect(find.byType(CaptureScreen), findsOneWidget);
    });

    testWidgets('an explicit initialIndex wins over a note that exists', (tester) async {
      await pump(
        tester,
        initialIndex: 0,
        repo: () => SynthesisRepository([_session()]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tabs(tester).index, 0);
      expect(find.byType(CaptureScreen), findsOneWidget);
    });

    testWidgets('an explicit initialIndex wins over no note', (tester) async {
      await pump(
        tester,
        initialIndex: 1,
        repo: () => SynthesisRepository(const []),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tabs(tester).index, 1);
    });

    testWidgets('notes still being loaded: no tab is drawn first, then the right one, with no jump', (tester) async {
      final release = Completer<void>();
      late _SlowRepository repo;
      await pump(
        tester,
        repo: () => repo = _SlowRepository(release, [_session()]),
      );
      await tester.pump();

      expect(find.byType(TabBar), findsNothing, reason: 'nothing to jump away from yet');
      expect(find.byType(CaptureScreen), findsNothing);
      expect(find.byType(SynthesisScreen), findsNothing);

      repo.finishLoading();
      await tester.pump();
      await tester.pump();

      expect(find.byType(TabBar), findsOneWidget);
      expect(tabs(tester).index, 1);
      expect(tabs(tester).animation!.value, 1.0, reason: 'opened on Synthesis, not slid there');
      expect(find.byType(CaptureScreen), findsNothing, reason: 'Capture was never built');
      final container = ProviderScope.containerOf(tester.element(find.byType(MainNavigationShell)));
      expect(container.read(selectedShellTabProvider), ShellTab.synthesis);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('notes loaded and none stored: Capture, drawn once loading is over', (tester) async {
      final release = Completer<void>();
      late _SlowRepository repo;
      await pump(
        tester,
        repo: () => repo = _SlowRepository(release, const []),
      );
      await tester.pump();
      expect(find.byType(TabBar), findsNothing);

      repo.finishLoading();
      await tester.pump();
      await tester.pump();

      expect(tabs(tester).index, 0);
      expect(find.byType(CaptureScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
