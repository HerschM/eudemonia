import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/capture/capture_inbox_ingestor.dart';
import 'package:eudemonia/features/capture/native_capture_channel.dart';
import 'package:eudemonia/features/capture/presentation/capture_screen.dart';
import 'package:eudemonia/features/home/main_navigation_shell.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/settings/background_permission_service.dart';
import 'package:eudemonia/features/synthesis/data/synthesis_repository.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_screen.dart';
import 'package:eudemonia/features/theme/widgets/clipboard_copy.dart';

import '../capture/capture_test_doubles.dart';
import '../settings/fake_permission_gateway.dart';

/// The record capsule lives in the navigation shell: on both tabs, and never under a SnackBar.
void main() {
  const channel = MethodChannel('com.eudemonia/hardware_buttons');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => call.method == 'isForegroundServiceRunning');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  late FakeNativeCaptureChannel native;

  Future<void> pumpShell(WidgetTester tester, {List<Note> notes = const [], int? maxDurationMs}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    native = FakeNativeCaptureChannel()
      ..maxDurationMs = maxDurationMs
      ..saveOnStop = const PendingCapture(path: '/inbox/1.wav', startedAtMs: 1700000000000);
    final repo = NotesRepository();
    for (final n in notes) {
      await repo.saveNote(n);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesRepositoryProvider.overrideWithValue(repo),
          runtimePermissionGatewayProvider.overrideWithValue(FakePermissionGateway()),
          nativeCaptureChannelProvider.overrideWithValue(native),
          captureInboxIngestorProvider.overrideWithValue(FakeCaptureInboxIngestor()),
          modelLifecycleManagerProvider.overrideWithValue(RecordingModelLifecycleManager()),
          synthesisRepositoryProvider.overrideWith(() => SynthesisRepository(const [])),
        ],
        child: const MaterialApp(home: MainNavigationShell(initialIndex: 0)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  Future<void> openSynthesis(WidgetTester tester) async {
    await tester.tap(find.text('Synthesis'));
    await tester.pumpAndSettle();
    expect(find.byType(SynthesisScreen), findsOneWidget);
  }

  testWidgets('the capsule shows on Capture and on Synthesis', (tester) async {
    await pumpShell(tester);
    expect(find.byKey(const Key('floating_capture_button')), findsOneWidget);
    expect(find.text('Tap to capture'), findsOneWidget);

    await openSynthesis(tester);
    expect(find.byKey(const Key('floating_capture_button')), findsOneWidget, reason: 'the same capsule, still there');
  });

  testWidgets('a recording started on Synthesis runs the same controller, shows its timer and the note number',
      (tester) async {
    await pumpShell(tester);
    await openSynthesis(tester);

    await tester.tap(find.byKey(const Key('floating_capture_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(native.state.isRecording, isTrue);
    expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget);
    expect(find.text('00:00 • Tap to Stop'), findsOneWidget, reason: 'native reported no limit: elapsed time only');

    await tester.tap(find.byKey(const Key('floating_capture_button_active')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(native.state.isRecording, isFalse);
    expect(find.text('Captured a new note [#01]'), findsOneWidget);
  });

  testWidgets('the timer shows the recording length limit native reports', (tester) async {
    await pumpShell(tester, maxDurationMs: 300000);

    await tester.tap(find.byKey(const Key('floating_capture_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('00:00 / 05:00 • Tap to Stop'), findsOneWidget);
  });

  testWidgets('the capsule state carries over when the tab changes', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const Key('floating_capture_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Synthesis'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('floating_capture_button_active')), findsOneWidget);
    expect(find.byKey(const Key('floating_capture_button')), findsNothing);
  });

  testWidgets('the Captured message does not overlap the capsule', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const Key('floating_capture_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('floating_capture_button_active')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // the SnackBar has slid in

    final snackBar = find.byType(SnackBar);
    final capsule = find.byKey(const Key('floating_capture_button'));
    expect(snackBar, findsOneWidget);
    expect(capsule, findsOneWidget);
    expect(rectOf(tester, snackBar).overlaps(rectOf(tester, capsule)), isFalse,
        reason: 'snackbar ${rectOf(tester, snackBar)} capsule ${rectOf(tester, capsule)}');
    expect(rectOf(tester, capsule).bottom, lessThanOrEqualTo(800), reason: 'still on screen');
  });

  testWidgets('a SnackBar shown from inside the Capture tab (Copied) does not overlap the capsule', (tester) async {
    await pumpShell(tester, notes: [Note(correctedText: 'Copy me.', state: ThoughtState.processed)]);

    await tester.tap(find.byKey(const Key('thought_copy_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final snackBar = find.byKey(const Key('copied_snackbar'));
    final capsule = find.byKey(const Key('floating_capture_button'));
    expect(snackBar, findsOneWidget);
    expect(rectOf(tester, snackBar).overlaps(rectOf(tester, capsule)), isFalse);
  });

  testWidgets('a SnackBar shown from inside the Synthesis tab does not overlap the capsule', (tester) async {
    await pumpShell(tester);
    await openSynthesis(tester);

    await copyToClipboard(tester.element(find.byType(SynthesisScreen)), 'text');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final snackBar = find.byKey(const Key('copied_snackbar'));
    final capsule = find.byKey(const Key('floating_capture_button'));
    expect(snackBar, findsOneWidget);
    expect(rectOf(tester, snackBar).overlaps(rectOf(tester, capsule)), isFalse);
  });

  testWidgets('the Capture screen on its own no longer draws a capsule', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [notesRepositoryProvider.overrideWithValue(NotesRepository())],
      child: const MaterialApp(home: CaptureScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('floating_capture_button')), findsNothing);
  });
}
